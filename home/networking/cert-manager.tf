# run ./script/update-cert-manager-secret.sh to update the secrets
resource "kubernetes_secret" "cert_manager_creds" {
  metadata {
    name      = "cert-manager-creds"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    norriswu_me_cf_dns_token = ""
    pawmery_pet_cf_dns_token = ""
  }
}

resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_secret.cert_manager_creds]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.18.2"

  values = [file("${path.module}/cert-manager-values.yaml")]
}

resource "helm_release" "cert_manager_config" {
  depends_on = [helm_release.cert_manager]

  namespace = kubernetes_namespace.this.metadata[0].name
  name      = "cert-manager-config"
  chart     = "${path.module}/charts/cert-manager"

  values = [file("${path.module}/cert-manager-config-values.yaml")]
}
