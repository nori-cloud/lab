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
  default = "external-secrets"
}

variable "infisical_host" {
  type        = string
  description = "Self-hosted Infisical instance URL"
  default     = "http://10.0.0.241"
}

variable "infisical_project_slug" {
  type        = string
  description = "Infisical project slug"
}

variable "infisical_environment" {
  type        = string
  description = "Infisical environment slug (e.g., dev, staging, prod)"
  default     = "prod"
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

# Secret for Infisical Universal Auth credentials
# Run ./script/update-external-secrets-secret.sh to populate
resource "kubernetes_secret" "infisical_credentials" {
  metadata {
    name      = "infisical-universal-auth"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    client_id     = ""
    client_secret = ""
  }
}

resource "helm_release" "external_secrets" {
  depends_on = [kubernetes_namespace.this]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "1.2.0"

  values = [file("${path.module}/external-secrets-values.yaml")]
}

resource "helm_release" "external_secrets_config" {
  depends_on = [helm_release.external_secrets, kubernetes_secret.infisical_credentials]

  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "external-secrets-config"
  chart     = "${path.module}/charts/external-secrets-config"

  set = [
    {
      name  = "infisical.host"
      value = var.infisical_host
    },
    {
      name  = "infisical.projectSlug"
      value = var.infisical_project_slug
    },
    {
      name  = "infisical.environment"
      value = var.infisical_environment
    }
  ]
}
