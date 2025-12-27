# helm repo add democratic-csi https://democratic-csi.github.io/charts/
# helm install my-democratic-csi democratic-csi/democratic-csi --version 0.15.0

# =============================================================================
# PREREQUISITE: Create credentials secret before deploying
# Run: ./setup-democratic-csi-secret.sh --username democratic-csi --password YOUR_PASSWORD
# =============================================================================

# This data source will fail if the secret doesn't exist
data "kubernetes_secret" "democratic_csi_config" {
  metadata {
    name      = "democratic-csi-driver-config"
    namespace = "democratic-csi"
  }
}

# Provide a helpful error message if secret is missing or empty
resource "null_resource" "validate_csi_secret" {
  triggers = {
    secret_exists = data.kubernetes_secret.democratic_csi_config.id
  }

  lifecycle {
    precondition {
      condition     = contains(keys(data.kubernetes_secret.democratic_csi_config.data), "driver-config-file.yaml")
      error_message = <<-EOT

        ============================================================
        ERROR: Democratic-CSI credentials secret not configured!
        ============================================================

        The secret exists but is missing the driver configuration.
        Run the setup script to create it properly:

          ./setup-democratic-csi-secret.sh --username democratic-csi --password YOUR_PASSWORD

        Then re-run: tofu apply
        ============================================================
      EOT
    }
  }
}

resource "helm_release" "democratic-csi" {
  depends_on = [
    kubectl_manifest.snapshot_crds,
    null_resource.validate_csi_secret,
    data.kubernetes_secret.democratic_csi_config
  ]

  namespace        = "democratic-csi"
  create_namespace = true

  name       = "democratic-csi"
  repository = "https://democratic-csi.github.io/charts/"
  chart      = "democratic-csi"
  version    = "0.15.0"

  values = [file("${path.module}/democratic-csi-values.yaml")]
}
