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

resource "aws_scheduler_schedule_group" "infra-schedule-group" {
  name = "infra-schedule-group"
}

resource "aws_scheduler_schedule" "infra_test_schedule" {
  name       = "infra-schedule-test"
  group_name = aws_scheduler_schedule_group.infra-schedule-group.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(*/15 * * * ? *)"

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.eb_scheduler_execution_role.arn

    input = jsonencode({
      action = "plan"
    })

    dead_letter_config {
      arn = aws_sqs_queue.dlq.arn
    }
  }

}

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

    input = jsonencode({
      action = "apply"
    })

    dead_letter_config {
      arn = aws_sqs_queue.dlq.arn
    }
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

    input = jsonencode({
      action = "destroy"
    })

    dead_letter_config {
      arn = aws_sqs_queue.dlq.arn
    }
  }
}