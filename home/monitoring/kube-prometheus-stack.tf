resource "helm_release" "kube_prometheus_stack" {
  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "kube-prometheus-stack"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "80.9.2"

  values = [file("${path.module}/values.yaml")]

  # CRDs can take time to be ready
  timeout = 600
}

# LoadBalancer service for Prometheus - accessible via MetalLB IP
resource "kubernetes_service_v1" "prometheus_lb" {
  depends_on = [helm_release.kube_prometheus_stack]

  metadata {
    name      = "prometheus-lb"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus"             = "kube-prometheus-stack-prometheus"
    }

    port {
      name        = "http-web"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }
  }
}

# LoadBalancer service for Alertmanager - accessible via MetalLB IP
resource "kubernetes_service_v1" "alertmanager_lb" {
  depends_on = [helm_release.kube_prometheus_stack]

  metadata {
    name      = "alertmanager-lb"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = "alertmanager"
      "alertmanager"           = "kube-prometheus-stack-alertmanager"
    }

    port {
      name        = "http-web"
      port        = 9093
      target_port = 9093
      protocol    = "TCP"
    }
  }
}

output "prometheus_lb_note" {
  value = "Run: kubectl get svc -n ${var.namespace} prometheus-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "alertmanager_lb_note" {
  value = "Run: kubectl get svc -n ${var.namespace} alertmanager-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
