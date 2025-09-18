terraform {
  required_providers {
    # https://registry.terraform.io/providers/bpg/proxmox/latest/docs
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.83.2"
    }
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
  }

  backend "s3" {
    bucket       = "infra-tf-033b4055b800d083"
    key          = "infra-home/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

provider "proxmox" {
  endpoint  = "https://192.168.0.100:8006/"
  api_token = var.proxmox_api_token
  insecure  = true
  ssh {
    agent    = true
    username = var.proxmox_username
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

locals {
  name = "nori-cloud"
}

module "proxmox" {
  source = "./proxmox"
}

module "cluster" {
  source = "./cluster"
}

output "cluster_ns" {
  value = module.cluster.all-ns
}

variable "tailscale_oauth_client_id" {
  type = string
}

variable "tailscale_oauth_client_secret" {
  type      = string
  sensitive = true
}

variable "cloudflare_dns_admin_token" {
  type      = string
  sensitive = true
}

module "networking" {
  depends_on = [module.cluster]
  source     = "./networking"

  namespace                     = "networking"
  tailscale_oauth_client_id     = var.tailscale_oauth_client_id
  tailscale_oauth_client_secret = var.tailscale_oauth_client_secret
  cloudflare_dns_admin_token     = var.cloudflare_dns_admin_token
}

module "system" {
  depends_on = [module.networking]
  source     = "./system"

  namespace = "system"
}
