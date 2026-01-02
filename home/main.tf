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

variable "deploy_democratic_csi_drivers" {
  type        = bool
  description = "Set to true after democratic-csi secrets are populated"
  default     = false
}

module "democratic_csi" {
  depends_on = [module.cluster]
  source     = "./_democratic-csi"

  namespace      = "democratic-csi"
  truenas_host   = "10.0.0.251"
  deploy_drivers = var.deploy_democratic_csi_drivers
}


module "external_secrets" {
  source = "./_external-secrets"

  namespace              = "external-secrets"
  infisical_host         = "https://infisical.home.norriswu.me"
  infisical_project_slug = "talos-v-czy"
  infisical_environment  = "prod"
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

module "argocd" {
  depends_on = [module.external_secrets]
  source     = "./_argocd"
}

module "system" {
  depends_on = [module.networking]
  source     = "./system"

  namespace = "system"
}
