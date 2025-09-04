variable "do_token" {
  type = string
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host  = module.cluster.host
  token = module.cluster.token
  cluster_ca_certificate = base64decode(
    module.cluster.ca_certificate
  )
}

provider "helm" {
  kubernetes = {
    host = module.cluster.host
    cluster_ca_certificate = base64decode(
      module.cluster.ca_certificate
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "doctl"
      args = ["kubernetes", "cluster", "kubeconfig", "exec-credential",
      "--version=v1beta1", module.cluster.id]
    }
  }
}
