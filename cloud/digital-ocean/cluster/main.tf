terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

variable "name" {
  type = string
}

resource "digitalocean_kubernetes_cluster" "dkc" {
  name    = var.name
  region  = "syd1"
  version = "1.33.1-do.3"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 1
  }
}

output "id" {
  value = digitalocean_kubernetes_cluster.dkc.id
}

output "host" {
  value = digitalocean_kubernetes_cluster.dkc.endpoint
}

output "token" {
  value = digitalocean_kubernetes_cluster.dkc.kube_config[0].token
}

output "ca_certificate" {
  value = digitalocean_kubernetes_cluster.dkc.kube_config[0].cluster_ca_certificate
}
