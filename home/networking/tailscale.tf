# =============================================================================
# PREREQUISITE: Create Tailscale OAuth credentials secret before deploying
# Run: ../script/update-tailscale-secret.sh
# =============================================================================

# This data source will fail if the secret doesn't exist
data "kubernetes_secret" "tailscale_oauth" {
  metadata {
    name      = "operator-oauth"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
}

# Provide a helpful error message if secret is missing or empty
resource "null_resource" "validate_tailscale_secret" {
  triggers = {
    secret_exists = data.kubernetes_secret.tailscale_oauth.id
  }

  lifecycle {
    precondition {
      condition     = contains(keys(data.kubernetes_secret.tailscale_oauth.data), "client_id") && contains(keys(data.kubernetes_secret.tailscale_oauth.data), "client_secret")
      error_message = <<-EOT

        ============================================================
        ERROR: Tailscale OAuth credentials secret not configured!
        ============================================================

        The secret exists but is missing required keys.
        Run the setup script to create it properly:

          cd /workspace/lab/home && ./script/update-tailscale-secret.sh

        Then re-run: tofu apply
        ============================================================
      EOT
    }
  }
}

resource "helm_release" "tailscale_operator" {
  depends_on = [
    null_resource.validate_tailscale_secret,
    data.kubernetes_secret.tailscale_oauth
  ]

  namespace  = kubernetes_namespace.this.metadata[0].name
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.92.4"

  # Don't set oauth credentials - operator will read from pre-created secret named "operator-oauth"
  # Secret must contain keys: client_id, client_secret
}
