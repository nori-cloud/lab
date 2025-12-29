resource "helm_release" "traefik" {
  depends_on = [
    helm_release.tailscale_operator,
    helm_release.metallb
  ]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "traefik"
  chart      = "traefik"
  repository = "https://helm.traefik.io/traefik"
  version    = "37.1.1"

  values = [file("${path.module}/traefik-values.yaml")]
}

# Secondary LoadBalancer service for Tailscale access
resource "kubernetes_service_v1" "traefik_tailscale" {
  depends_on = [helm_release.traefik]

  metadata {
    name      = "traefik-tailscale"
    namespace = kubernetes_namespace.this.metadata[0].name
    annotations = {
      "tailscale.com/hostname" = "traefik"
    }
  }

  spec {
    type                = "LoadBalancer"
    load_balancer_class = "tailscale"

    selector = {
      "app.kubernetes.io/name"     = "traefik"
      "app.kubernetes.io/instance" = "traefik"
    }

    port {
      name        = "web"
      port        = 80
      target_port = "web"
      protocol    = "TCP"
    }

    port {
      name        = "websecure"
      port        = 443
      target_port = "websecure"
      protocol    = "TCP"
    }
  }
}
