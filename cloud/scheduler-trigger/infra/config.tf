resource "aws_ssm_parameter" "discord_webhook_url" {
  name  = "/infra-scheduler-trigger/config/DISCORD_WEBHOOK_URL"
  type  = "String"
  value = "https://discord.com/api/webhooks/1406911642528251965/GfVcKiwzT6QJJv7IIOWdbW_LcZq1E81z-eC5b84p4s1iM7X-BBJYX5S_adhq8UkA0DoC"
}

resource "aws_ssm_parameter" "github_token" {
  name  = "/infra-scheduler-trigger/config/GITHUB_TOKEN"
  type  = "String"
  value = "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"
}

resource "aws_ssm_parameter" "github_workflow_id" {
  name  = "/infra-scheduler-trigger/config/GITHUB_WORKFLOW_ID"
  type  = "String"
  value = "infra-scheduler.yaml"
}

resource "aws_ssm_parameter" "github_workflow_ref" {
  name  = "/infra-scheduler-trigger/config/GITHUB_WORKFLOW_REF"
  type  = "String"
  value = "main"
}

