terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "namespace" {
  type = string
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}
