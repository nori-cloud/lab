resource "kubernetes_manifest" "teleport-cluster-certificate-secret" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "teleport-certificate"
      namespace = kubernetes_namespace.this.metadata[0].name
    }
    spec = {
      secretName = "teleport-certificate-secret"
      issuerRef = {
        name = "cloudflare-cluster-issuer"
        kind = "ClusterIssuer"
      }
      commonName = "teleport.norriswu.me"
      dnsNames = [
        "teleport.norriswu.me",
        "*.teleport.norriswu.me"
      ]
    }
  }
}

resource "helm_release" "teleport" {
  depends_on = [
    kubernetes_manifest.teleport-cluster-certificate-secret
  ]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "teleport"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-cluster"
  version    = "18.2.2"

  values = [file("${path.module}/teleport-cluster-values.yaml")]
}
