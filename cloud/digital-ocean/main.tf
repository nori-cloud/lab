terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "infra-do/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

locals {
  name = "nori-cloud"
}

variable "cloudflare_dns_admin_token" {
  type      = string
  sensitive = true
}

module "cluster" {
  source = "./cluster"
  name   = "${local.name}-cluster"
}

output "cluster_id" {
  value = module.cluster.id
}

module "networking" {
  depends_on = [module.cluster]
  source     = "./networking"

  cloudflare_dns_admin_token = var.cloudflare_dns_admin_token
}

module "butler" {
  depends_on = [module.networking]
  source     = "./butler"
}
