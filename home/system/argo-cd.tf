resource "kubernetes_secret" "argocd-oauth-client" {
  metadata {
    name = "argocd-oauth-client"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    client_id = ""
    client_secret = ""
  }
}

resource "helm_release" "argo-cd" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "8.3.4"

  values = [file("${path.module}/argo-cd-values.yaml")]
}