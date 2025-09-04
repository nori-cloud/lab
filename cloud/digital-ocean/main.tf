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
}

variable "do_token" {
  type = string
}

# variable "aws_region" {
#   type = string
# }

provider "digitalocean" {
  token = var.do_token
}

locals {
  name = "nori-cloud"
}

resource "digitalocean_kubernetes_cluster" "dkc" {
  name    = "${local.name}-cluster"
  region  = "syd1"
  version = "1.33.1-do.3"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
  }

  destroy_all_associated_resources = true
}


provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.dkc.endpoint
  token = digitalocean_kubernetes_cluster.dkc.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.dkc.kube_config[0].cluster_ca_certificate
  )
}

output "cluster_id" {
  value = digitalocean_kubernetes_cluster.dkc.id
}


provider "helm" {
  kubernetes = {
    host = digitalocean_kubernetes_cluster.dkc.endpoint
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.dkc.kube_config[0].cluster_ca_certificate
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "doctl"
      args = ["kubernetes", "cluster", "kubeconfig", "exec-credential",
      "--version=v1beta1", digitalocean_kubernetes_cluster.dkc.id]
    }
  }
}

variable "cloudflare_dns_admin_token" {
  type      =  string
  sensitive = true
}

module "networking" {
  depends_on = [digitalocean_kubernetes_cluster.dkc]
  source     = "./networking"

  cloudflare_dns_admin_token = var.cloudflare_dns_admin_token
}
