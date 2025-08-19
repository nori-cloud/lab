resource "aws_ssm_parameter" "discord_message_webhook" {
  name  = "/infra-scheduler-trigger/config/discord_message_webhook"
  type  = "String"
  value = "https://discord.com/api/webhooks/1406911642528251965/GfVcKiwzT6QJJv7IIOWdbW_LcZq1E81z-eC5b84p4s1iM7X-BBJYX5S_adhq8UkA0DoC"
}

resource "aws_ssm_parameter" "github_token" {
  name  = "/infra-scheduler-trigger/config/github_token"
  type  = "String"
  value = "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"
}

resource "aws_ssm_parameter" "github_workflow_id" {
  name  = "/infra-scheduler-trigger/config/github_workflow_id"
  type  = "String"
  value = "infra-scheduler.yaml"
}

resource "aws_ssm_parameter" "github_workflow_ref" {
  name  = "/infra-scheduler-trigger/config/github_workflow_ref"
  type  = "String"
  value = "main"
}

