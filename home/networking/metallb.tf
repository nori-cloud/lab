resource "helm_release" "metallb" {
  namespace  = kubernetes_namespace.this.metadata[0].name
  name       = "metallb"
  chart      = "metallb"
  repository = "https://metallb.github.io/metallb"
  version    = "0.15.2"

  # Required for Talos control plane nodes
  # See: https://github.com/siderolabs/talos/issues/10291
  set = [
    {
      name  = "speaker.ignoreExcludeLB"
      value = "true"
    }
  ]
}

resource "helm_release" "metallb_address_config" {
  depends_on = [helm_release.metallb]

  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "metallb-address-config"
  chart     = "${path.module}/charts/metallb"

  set = [
    {
      name  = "namespace"
      value = kubernetes_namespace.this.metadata[0].name
    },
    {
      name  = "pool.name"
      value = "nori-cloud-pool"
    },
    {
      name  = "pool.addresses[0]"
      value = "10.0.0.50-10.0.0.99"
    }
  ]
}
