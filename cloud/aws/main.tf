terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "infra/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }

  required_version = "1.10.5"
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Namespace = "${local.name}-infra"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}


data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "nori-cloud"
  azs  = data.aws_availability_zones.available.names
  cluster = {
    version    = "1.33"
    admin_role = "arn:aws:iam::442228337792:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_AdministratorAccess_38aa147304c4b3e0"
  }
  vpc = {
    cidr         = "10.0.0.0/16"
    subnet_count = 3
  }
}
