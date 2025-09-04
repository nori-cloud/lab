resource "kubernetes_deployment" "whoami" {
  metadata {
    name      = "whoami"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "whoami"
      }
    }
    template {
      metadata {
        labels = {
          app = "whoami"
        }
      }
      spec {
        container {
          name  = "whoami"
          image = "traefik/whoami"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "whoami" {
  metadata {
    name      = "whoami"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    port {
      port = 80
    }
    selector = {
      app = "whoami"
    }
  }
}

resource "kubernetes_manifest" "whoami" {
  manifest = {

    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"

    metadata = {
      name      = "whoami"
      namespace = kubernetes_namespace.this.metadata[0].name
    }

    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`whoami.norriswu.me`)"
          kind  = "Rule"
          services = [
            {
              name = "whoami"
              port = 80
            }
          ]
        }
      ]
    }
  }
}
