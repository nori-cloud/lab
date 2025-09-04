resource "kubernetes_deployment" "actual-budget" {
  metadata {
    name      = "actual-budget"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    selector {
      match_labels = {
        app = "actual-budget"
      }
    }
    template {
      metadata {
        labels = {
          app = "actual-budget"
        }
      }

      # docker run --pull=always --restart=unless-stopped  -v YOUR/PATH/TO/DATA:/data
      spec {
        container {
          name  = "actual-budget"
          image = "actualbudget/actual-server:latest-alpine"
          port {
            container_port = 8000
          }

          env {
            name  = "ACTUAL_OPENID_DISCOVERY_URL"
            value = "https://authentik.norriswu.me/application/o/actual-budget/"
          }

          env {
            name  = "ACTUAL_OPENID_CLIENT_ID"
            value = "7aKHH6afPhNtML0S3BKIzparuRIxAXD4bMvOXxUs"
          }

          env {
            name  = "ACTUAL_OPENID_CLIENT_SECRET"
            value = "Gvfv53HN8rXI31A8TqZ8GlCVljO00jJehXTL4qCZr0Mflz8LzoGZ3rtnusGx6YWJRtrcUoe8r95Fio0b0IJxFUBlNb1aq31py1Sn5YKSluieJQSMPyuoMSZbq5RaNGUz"
          }

          env {
            name  = "ACTUAL_OPENID_SERVER_HOSTNAME"
            value = "https://actual-budget.norriswu.me"
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "actual-budget" {
  metadata {
    name      = "actual-budget"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    port {
      port = 5006
    }
    selector = {
      app = "actual-budget"
    }
  }
}

resource "kubernetes_manifest" "actual-budget" {
  manifest = {

    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"

    metadata = {
      name      = "actual-budget"
      namespace = kubernetes_namespace.this.metadata[0].name
    }

    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`actual-budget.norriswu.me`)"
          kind  = "Rule"
          services = [
            {
              name = "actual-budget"
              port = 5006
            }
          ]
        }
      ]
    }
  }
}
