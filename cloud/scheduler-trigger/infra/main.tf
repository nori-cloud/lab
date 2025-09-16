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

  required_version = ">=1.10"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Namespace = "nori-infra-scheduler"
    }
  }
}

variable "image_tag" {
  description = "Docker image tag for the Lambda function (git commit SHA or version)"
  type        = string
  default     = "latest"

  validation {
    condition     = length(var.image_tag) > 0
    error_message = "Image tag cannot be empty."
  }
}
