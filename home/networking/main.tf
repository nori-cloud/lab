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

# resource "helm_release" "external-dns" {
#   depends_on = [kubernetes_secret.cloudflare_creds]

#   namespace = kubernetes_namespace.this.metadata[0].name

#   name       = "external-dns"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "external-dns"
#   version    = "9.0.3"

#   values = [file("${path.module}/external-dns-values.yaml")]
# }

# resource "helm_release" "metal_lb" {
#   namespace  = kubernetes_namespace.this.metadata[0].name
#   name       = "metal-lb"
#   chart      = "metallb"
#   repository = "https://metallb.github.io/metallb"
#   version    = "0.15.2"
# }

# resource "helm_release" "metallb_address_config" {
#   depends_on = [helm_release.metal_lb]

#   namespace = kubernetes_namespace.this.metadata[0].name
#   name      = "metallb-address-config"
#   chart     = "${path.module}/charts/metallb"

#   set = [
#     {
#       name  = "namespace"
#       value = kubernetes_namespace.this.metadata[0].name
#     },
#     {
#       name  = "pool.name"
#       value = "home-cluster-pool"
#     },
#   ]

#   set_list = [
#     {
#       name  = "pool.addresses"
#       value = ["192.168.0.150-192.168.0.254"]
#     }
#   ]
# }

variable "tailscale_oauth_client_id" {
  type = string
}

variable "tailscale_oauth_client_secret" {
  type      = string
  sensitive = true
}

resource "helm_release" "tailscale_operator" {
  namespace  = kubernetes_namespace.this.metadata[0].name
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.86.5"

  set = [
    {
      name  = "oauth.clientId"
      value = var.tailscale_oauth_client_id
    },
    {
      name  = "oauth.clientSecret"
      value = var.tailscale_oauth_client_secret
    }
  ]
}

variable "cloudflare_dns_admin_token" {
  type      = string
  sensitive = true
}

resource "kubernetes_secret" "cloudflare_creds" {
  metadata {
    name      = "cloudflare-creds"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    cloudflare_api_token = var.cloudflare_dns_admin_token
  }
}

resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_secret.cloudflare_creds]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.18.2"

  values = [file("${path.module}/certmanager-values.yaml")]
}

resource "helm_release" "cert_manager_config" {
  depends_on = [helm_release.cert_manager]

  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "cert-manager-config"
  chart     = "${path.module}/charts/cert-manager"

  set = [
    {
      name  = "namespace"
      value = kubernetes_namespace.this.metadata[0].name
    },
    {
      name  = "email"
      value = "norris.wu.au@outlook.com"
    }
  ]

  set_list = [
    {
      name  = "dnsZone"
      value = ["norriswu.me"]
    }
  ]
}

resource "helm_release" "traefik" {
  depends_on = [helm_release.tailscale_operator]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "traefik"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"
  version    = "37.1.1"

  values = [file("${path.module}/traefik-values.yaml")]
}
