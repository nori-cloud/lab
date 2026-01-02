variable "namespace" {
  type = string
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}
