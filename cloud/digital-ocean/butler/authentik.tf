resource "helm_release" "authentik" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "authentik"
  repository = "https://charts.goauthentik.io"
  chart      = "authentik"
  version    = "2025.8.1"

  values = [file("${path.module}/authentik-values.yaml")]
}

resource "kubernetes_manifest" "authentik_middleware" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "authentik"
      namespace = kubernetes_namespace.this.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address            = "http://authentik.norriswu.me/outpost.goauthentik.io/auth/traefik"
        trustForwardHeader = true
        authResponseHeaders = [
          "X-authentik-username",
          "X-authentik-groups",
          "X-authentik-entitlements",
          "X-authentik-email",
          "X-authentik-name",
          "X-authentik-uid",
          "X-authentik-jwt",
          "X-authentik-meta-jwks",
          "X-authentik-meta-outpost",
          "X-authentik-meta-provider",
          "X-authentik-meta-app",
          "X-authentik-meta-version",
        ],
      }
    }
  }
}
