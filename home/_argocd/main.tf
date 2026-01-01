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
  default = "argo-cd"
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "pre_install_config" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name  = "argo-cd-pre-install-config"
  chart = "${path.module}/charts/pre-install-config"
}

resource "helm_release" "argo_cd" {
  depends_on = [helm_release.pre_install_config]
  namespace  = kubernetes_namespace.this.metadata[0].name

  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.5.7"

  values = [file("${path.module}/argo-cd-values.yaml")]
}

resource "helm_release" "argo_cd_config" {
  depends_on = [helm_release.argo_cd]
  namespace = kubernetes_namespace.this.metadata[0].name

  name  = "argo-cd-config"
  chart = "${path.module}/charts/argo-cd-config"

  values = [file("${path.module}/argo-cd-config-values.yaml")]
}
