terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }

  required_version = "1.10.5"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Name = "nori-infra"
    }
  }
}