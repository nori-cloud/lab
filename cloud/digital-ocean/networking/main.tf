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

resource "kubernetes_namespace" "networking_ns" {
  metadata {
    name = "nori-net"
  }
}

variable "cloudflare_dns_admin_token" {
  type      = string
  sensitive = true
}

resource "kubernetes_secret" "cloudflare_creds" {
  metadata {
    name      = "cloudflare-creds"
    namespace = kubernetes_namespace.networking_ns.metadata[0].name
  }

  data = {
    cloudflare_api_token = var.cloudflare_dns_admin_token
  }
}

resource "helm_release" "external-dns" {
  depends_on = [kubernetes_secret.cloudflare_creds]

  namespace = kubernetes_namespace.networking_ns.metadata[0].name

  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "9.0.3"

  set = [
    { name  = "namespace"
      value = kubernetes_namespace.networking_ns.metadata[0].name
    },
    {
      name  = "provider"
      value = "cloudflare"
    },
    {
      name  = "cloudflare.secretName"
      value = kubernetes_secret.cloudflare_creds.metadata[0].name
    }
  ]
}

resource "helm_release" "traefik" {
  depends_on = [kubernetes_secret.cloudflare_creds]

  namespace = kubernetes_namespace.networking_ns.metadata[0].name

  name       = "traefik"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"

  values = [file("${path.module}/traefik-values.yaml")]

  timeout = 10 * 60 // takes time for load balancer to become available
}
