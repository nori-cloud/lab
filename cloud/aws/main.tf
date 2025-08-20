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
      Namespace = "nori-infra"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }

  registries = [
    {
      url      = "oci://localhost:5000"
      username = "username"
      password = "password"
    },
    {
      url      = "oci://private.registry"
      username = "username"
      password = "password"
    }
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}


locals {
    azs = data.aws_availability_zones.available.names
    cluster = {
        name = "nori-cluster"
        version = "1.33"
    }
    vpc = {
        cidr = "10.0.0.0/16"
        subnet_count = 3
    }
}
