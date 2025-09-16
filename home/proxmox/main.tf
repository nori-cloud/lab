terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_download_file" "debian_13_amd64_netinst" {
  content_type       = "iso"
  datastore_id       = "local"
  file_name          = "debian-13.1.0-amd64-netinst.iso"
  node_name          = "proxmox"
  url                = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
  checksum           = "873e9aa09a913660b4780e29c02419f8fb91012c8092e49dcfe90ea802e60c82dcd6d7d2beeb92ebca0570c49244eee57a37170f178a27fe1f64a334ee357332"
  checksum_algorithm = "sha512"
}
