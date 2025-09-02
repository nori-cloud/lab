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
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
  }
}

variable "do_token" {
  type = string
}

variable "aws_region" {
  type = string
}

provider "digitalocean" {
  token = var.do_token
}

provider "aws" {
  region     = var.aws_region
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
    host  = digitalocean_kubernetes_cluster.dkc.endpoint
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

resource "kubernetes_namespace" "nori-space" {
  metadata {
    name = "nori-space"
  }
}

resource "helm_release" "nginx" {
  namespace = kubernetes_namespace.nori-space.metadata[0].name

  name       = "nginx"
  chart      = "nginx"
  repository = "https://charts.bitnami.com/bitnami"
  version = "21.1.23"

  values = [file("${path.module}/nginx-values.yaml")]
}

resource "helm_release" "traefik" {
  namespace = kubernetes_namespace.nori-space.metadata[0].name

  name       = "traefik"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"

  values = [file("${path.module}/traefik-values.yaml")]

  timeout = 30 * 60 // takes time for load balancer to become available

  depends_on = [kubernetes_secret.aws_credentials]
}
