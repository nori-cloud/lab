terraform {
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    # https://registry.terraform.io/providers/hashicorp/helm/latest/docs
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    # https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "infra-home/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
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

provider "kubectl" {
  config_path = "~/.kube/config"
}

locals {
  name = "nori-cloud"
}

module "cluster" {
  source = "./cluster"
}

output "cluster_ns" {
  value = module.cluster.all-ns
}

module "networking" {
  depends_on = [module.cluster]
  source     = "./networking"

  namespace = "networking"
}

module "authentik" {
  depends_on = [module.networking]
  source     = "./_authentik"
}

module "system" {
  depends_on = [module.networking]
  source     = "./system"

  namespace = "system"
}
