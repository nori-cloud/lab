terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "scheduler-trigger/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }

  required_version = "1.10.5"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Namespace = "nori-infra-scheduler"
    }
  }
}

resource "aws_ecr_repository" "this" {
  name                 = "infra-scheduler-trigger"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the 10 most recent tagged images"
        selection = {
          tagStatus     = "tagged"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# NEED TO APPLY THE ABOVE FIRST

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "infra-scheduler-trigger-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "infra-scheduler-trigger-dlq"
  message_retention_seconds = 1209600 # 14 days
  
  tags = {
    Purpose = "Dead letter queue for scheduler Lambda failures"
  }
}

# IAM policy for Lambda to send messages to DLQ
data "aws_iam_policy_document" "lambda_dlq_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [
      aws_sqs_queue.dlq.arn
    ]
  }
}

resource "aws_iam_policy" "lambda_dlq_policy" {
  name   = "lambda-dlq-policy"
  policy = data.aws_iam_policy_document.lambda_dlq_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_dlq_policy" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_dlq_policy.arn
}

resource "aws_lambda_function" "this" {
  function_name = "infra-scheduler-trigger"
  role          = aws_iam_role.this.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.this.repository_url}:latest"

  memory_size = 512
  timeout     = 30

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
}

resource "aws_lambda_permission" "allow_eventbridge_scheduler" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = "arn:aws:scheduler:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:schedule/*/*"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eb_scheduler_execution_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eb_scheduler_execution_role" {
  name               = "eb-scheduler-execution-role"
  assume_role_policy = data.aws_iam_policy_document.eb_scheduler_execution_role_policy.json
}

data "aws_iam_policy_document" "scheduler_lambda_invoke" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.this.arn
    ]
  }
}

resource "aws_iam_policy" "scheduler_lambda_invoke" {
  name   = "scheduler-lambda-invoke-policy"
  policy = data.aws_iam_policy_document.scheduler_lambda_invoke.json
}

resource "aws_iam_role_policy_attachment" "scheduler_lambda_invoke" {
  role       = aws_iam_role.eb_scheduler_execution_role.name
  policy_arn = aws_iam_policy.scheduler_lambda_invoke.arn
}

resource "aws_scheduler_schedule_group" "infra-schedule-group" {
  name = "infra-schedule-group"
}

# resource "aws_scheduler_schedule" "infra_test_schedule" {
#   name       = "infra-schedule-test"
#   group_name = aws_scheduler_schedule_group.infra-schedule-group.name

#   flexible_time_window {
#     mode = "OFF"
#   }

#   schedule_expression = "cron(*/5 * * * ? *)"

#   target {
#     arn      = aws_lambda_function.this.arn
#     role_arn = aws_iam_role.eb_scheduler_execution_role.arn
#   }
# }

resource "aws_scheduler_schedule" "infra_start_up_schedule" {
  name       = "infra-schedule-start-up"
  group_name = aws_scheduler_schedule_group.infra-schedule-group.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(30 22 ? * FRI,SAT *)"

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.eb_scheduler_execution_role.arn
  }
}

resource "aws_scheduler_schedule" "infra_shutdown_schedule" {
  name       = "infra-schedule-shutdown"
  group_name = aws_scheduler_schedule_group.infra-schedule-group.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 2 ? * SAT,SUN *)"

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.eb_scheduler_execution_role.arn
  }
}

# CloudWatch Log Group for Lambda (explicit creation for retention control)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

# CloudWatch Alarm: Lambda Function Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "infra-scheduler-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda errors"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: Lambda Function Duration (close to timeout)
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "infra-scheduler-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000" # 25 seconds (close to 30s timeout)
  alarm_description   = "This metric monitors lambda execution duration"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: Lambda Function Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "infra-scheduler-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda throttles"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: EventBridge Scheduler Failed Invocations
resource "aws_cloudwatch_metric_alarm" "scheduler_failed_invocations" {
  alarm_name          = "infra-scheduler-failed-invocations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Scheduler"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors EventBridge Scheduler failed invocations"

  dimensions = {
    ScheduleGroup = aws_scheduler_schedule_group.infra-schedule-group.name
  }

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: DLQ Messages (indicates Lambda failures)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "infra-scheduler-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors DLQ for failed Lambda executions"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  treat_missing_data = "notBreaching"
}
