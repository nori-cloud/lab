resource "kubernetes_secret" "argocd-oauth-client" {
  metadata {
    name      = "argocd-oauth-client"
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    client-id     = ""
    client-secret = ""
  }
}

resource "helm_release" "argo-cd" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.5.7"

  values = [file("${path.module}/argo-cd-values.yaml")]
}

resource "helm_release" "argo-cd-config" {
  depends_on = [helm_release.argo-cd]

  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "argo-cd-config"
  chart     = "${path.module}/charts/argo-cd-config"
}
