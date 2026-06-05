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
  version    = "9.2.3"

  values = [file("${path.module}/argo-cd-values.yaml")]
}

resource "helm_release" "argo_cd_app_set_config" {
  depends_on = [helm_release.argo_cd]
  namespace  = kubernetes_namespace.this.metadata[0].name

  name  = "argo-cd-app-set-config"
  chart = "${path.module}/charts/app-set-config"

  values = [file("${path.module}/app-set-config-values.yaml")]
}
