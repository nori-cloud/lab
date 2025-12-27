# VolumeSnapshot CRDs required by democratic-csi
# https://github.com/kubernetes-csi/external-snapshotter
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
