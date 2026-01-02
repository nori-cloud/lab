terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}

variable "namespace" {
  type    = string
  default = "democratic-csi"
}

variable "truenas_host" {
  type        = string
  description = "TrueNAS host IP or hostname"
  default     = "10.0.0.251"
}

variable "deploy_drivers" {
  type        = bool
  description = "Set to true after secrets are populated to deploy helm charts"
  default     = false
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

# =============================================================================
# VolumeSnapshot CRDs required by democratic-csi
# https://github.com/kubernetes-csi/external-snapshotter
# =============================================================================

locals {
  snapshot_crd_version = "v8.0.1"
  snapshot_crds = [
    "snapshot.storage.k8s.io_volumesnapshotclasses.yaml",
    "snapshot.storage.k8s.io_volumesnapshotcontents.yaml",
    "snapshot.storage.k8s.io_volumesnapshots.yaml",
  ]
}

data "http" "snapshot_crds" {
  for_each = toset(local.snapshot_crds)
  url      = "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/${local.snapshot_crd_version}/client/config/crd/${each.value}"
}

resource "kubectl_manifest" "snapshot_crds" {
  for_each  = toset(local.snapshot_crds)
  yaml_body = data.http.snapshot_crds[each.key].response_body
}

# =============================================================================
# Secrets for driver configuration
# Run: ./setup-secrets.sh to populate these
# =============================================================================

resource "kubernetes_secret" "iscsi_config" {
  metadata {
    name      = "democratic-csi-iscsi-config"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    "driver-config-file.yaml" = ""
  }

  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_secret" "nfs_config" {
  metadata {
    name      = "democratic-csi-nfs-config"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    "driver-config-file.yaml" = ""
  }

  lifecycle {
    ignore_changes = [data]
  }
}

# =============================================================================
# iSCSI Driver (freenas-iscsi)
# =============================================================================

resource "helm_release" "iscsi" {
  count = var.deploy_drivers ? 1 : 0

  depends_on = [
    kubectl_manifest.snapshot_crds,
    kubernetes_secret.iscsi_config,
  ]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "democratic-csi-iscsi"
  repository = "https://democratic-csi.github.io/charts/"
  chart      = "democratic-csi"
  version    = "0.15.0"

  values = [file("${path.module}/iscsi-values.yaml")]
}

# =============================================================================
# NFS Driver (freenas-nfs)
# =============================================================================

resource "helm_release" "nfs" {
  count = var.deploy_drivers ? 1 : 0

  depends_on = [
    kubectl_manifest.snapshot_crds,
    kubernetes_secret.nfs_config,
  ]

  namespace = kubernetes_namespace.this.metadata[0].name

  name       = "democratic-csi-nfs"
  repository = "https://democratic-csi.github.io/charts/"
  chart      = "democratic-csi"
  version    = "0.15.0"

  values = [file("${path.module}/nfs-values.yaml")]
}
