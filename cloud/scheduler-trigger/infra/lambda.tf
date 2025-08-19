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

resource "aws_lambda_function" "this" {
  function_name = "infra-scheduler-trigger"
  role          = aws_iam_role.this.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"

  memory_size = 512
  timeout     = 30

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      DISCORD_MESSAGE_WEBHOOK = aws_ssm_parameter.discord_message_webhook.value
      GITHUB_TOKEN        = aws_ssm_parameter.github_token.value
      GITHUB_WORKFLOW_ID  = aws_ssm_parameter.github_workflow_id.value
      GITHUB_WORKFLOW_REF = aws_ssm_parameter.github_workflow_ref.value
    }
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
