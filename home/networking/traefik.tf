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
