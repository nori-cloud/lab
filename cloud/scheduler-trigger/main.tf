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

# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "example" {
#   name               = "lambda_execution_role"
#   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# }

# resource "aws_iam_role" "this" {
#   name = "infra-scheduler-trigger"
# }

# resource "aws_lambda_function" "example" {
#   function_name = "example_container_function"
#   role          = aws_iam_role.example.arn
#   package_type  = "Image"
#   image_uri     = "${aws_ecr_repository.this.repository_url}:latest"

#   image_config {
#     entry_point = ["/lambda-entrypoint.sh"]
#     command     = ["app.handler"]
#   }

#   memory_size = 512
#   timeout     = 30

#   architectures = ["arm64"] # Graviton support for better price/performance
# }
