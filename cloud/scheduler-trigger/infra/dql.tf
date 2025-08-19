resource "aws_sqs_queue" "dlq" {
  name                      = "infra-scheduler-trigger-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Purpose = "Dead letter queue for scheduler Lambda failures"
  }
}

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

resource "aws_iam_role_policy_attachment" "scheduler_dlq_policy" {
  role       = aws_iam_role.eb_scheduler_execution_role.name
  policy_arn = aws_iam_policy.lambda_dlq_policy.arn
}
