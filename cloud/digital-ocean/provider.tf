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
    host  = module.cluster.host
    token = module.cluster.token
    cluster_ca_certificate = base64decode(
      module.cluster.ca_certificate
    )
  }
}
