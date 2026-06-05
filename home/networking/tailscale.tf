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

  # Expose the Kubernetes API server over the tailnet for remote kubectl access.
  # The operator runs an API server proxy reachable at
  # https://tailscale-operator.<tailnet>.ts.net. In auth mode it authenticates
  # the tailnet identity and impersonates a Kubernetes group, so in-cluster RBAC
  # applies per user.
  #
  # Chart values are quoted strings ("true"/"false"/"noauth"); force string type
  # so helm doesn't coerce them to booleans and break the chart's comparisons.
  #
  # Requires a Tailscale ACL grant mapping tailnet users to a Kubernetes group,
  # e.g. (in the tailnet policy file):
  #   "grants": [{
  #     "src": ["autogroup:admin"],
  #     "dst": ["tag:k8s-operator"],
  #     "app": { "tailscale.com/cap/kubernetes": [{ "impersonate": { "groups": ["system:masters"] } }] }
  #   }]
  set = [
    {
      name  = "apiServerProxyConfig.mode"
      value = "true"
      type  = "string"
    },
    {
      name  = "apiServerProxyConfig.allowImpersonation"
      value = "true"
      type  = "string"
    }
  ]
}
