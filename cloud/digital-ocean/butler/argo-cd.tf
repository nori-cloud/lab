resource "helm_release" "argo-cd" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  version = "8.3.4"

  values = [file("${path.module}/argo-cd-values.yaml")]
}