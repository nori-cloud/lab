terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    null = {
      source = "hashicorp/null"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}

data "kubernetes_all_namespaces" "allns" {}

output "all-ns" {
  value = data.kubernetes_all_namespaces.allns.namespaces
}
