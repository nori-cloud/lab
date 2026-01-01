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
  type    = string
  default = "authentik"
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "authentik_config" {
  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "authentik-config"
  chart     = "${path.module}/charts/config"
}

resource "helm_release" "authentik" {
  depends_on = [helm_release.authentik_config]
  namespace  = kubernetes_namespace.this.metadata[0].name

  name       = "authentik"
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = "2025.10.3"

  values = [file("${path.module}/values.yaml")]
}
