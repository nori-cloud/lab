terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  node = "proxmox"
  images = {
    ubuntu = {
      content_type       = "iso"
      file_name          = "ubuntu-24.04.3-live-server-amd64.iso"
      url                = "https://mirror.internet.asn.au/pub/ubuntu/releases/24.04/ubuntu-24.04.3-live-server-amd64.iso"
      checksum           = "c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
      checksum_algorithm = "sha256"
    },
    ubuntu_ct = {
      content_type = "vztmpl"
      url          = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    },
    opnsense = {
      content_type       = "iso"
      file_name          = "OPNsense-25.7-dvd-amd64.iso"
      url                = "https://mirror.aarnet.edu.au/pub/opnsense/releases/mirror/OPNsense-25.7-dvd-amd64.iso.bz2"
      checksum           = "fa4b30df3f5fd7a2b1a1b2bdfaecfe02337ee42f77e2d0ae8a60753ea7eb153e"
      checksum_algorithm = "sha256"
    },
    debian = {
      content_type       = "iso"
      file_name          = "debian-13.1.0-amd64-netinst.iso"
      url                = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
      checksum           = "873e9aa09a913660b4780e29c02419f8fb91012c8092e49dcfe90ea802e60c82dcd6d7d2beeb92ebca0570c49244eee57a37170f178a27fe1f64a334ee357332"
      checksum_algorithm = "sha512"
    },
    debian_ct = {
      content_type = "vztmpl"
      url          = "http://download.proxmox.com/images/system/debian-13-standard_13.1-1_amd64.tar.zst"
    }
  }
}

resource "proxmox_virtual_environment_download_file" "images" {
  for_each = local.images

  content_type       = each.value.content_type
  datastore_id       = "local"
  file_name          = try(each.value.file_name, null)
  node_name          = local.node
  url                = each.value.url
  checksum           = try(each.value.checksum, null)
  checksum_algorithm = try(each.value.checksum_algorithm, null)
}

# resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
#   name = "terraform-k3s-cluster"
#   description = "Managed by Terraform"

#   node_name = local.node
#   vm_id     = 200

#   agent {
#     enabled = false
#   }

#   cpu {
#     cores = 2
#   }



#   memory {
#     dedicated = 4096
#     floating  = 4096 # set equal to dedicated to enable ballooning
#   }

#   disk {
#     datastore_id = "local-lvm"
#     import_from  = proxmox_virtual_environment_download_file.images["ubuntu"].id
#     interface    = "scsi0"
#   }

#   initialization {
#     ip_config {
#       ipv4 {
#         address = "192.168.0.200/24"
#         gateway = "192.168.0.1"
#       }
#     }

#     user_account {
#       keys     = [trimspace(tls_private_key.ubuntu_vm_key.public_key_openssh)]
#       password = random_password.ubuntu_vm_password.result
#       username = "ubuntu"
#     }

#     user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
#   }

#   network_device {
#     bridge = "vmbr0"
#   }

#   operating_system {
#     type = "l26"
#   }
# }

# resource "proxmox_virtual_environment_file" "cloud_config" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = local.node
#   file_mode    = "0700"

#   source_raw {
#     data      = <<-EOF
#       #!/usr/bin/env bash

#       echo "Running hook script"
#       apt-get update
#       apt-get install -y curl qemu-guest-agent

#       curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable servicelb,traefik" sh -

#       EOF
#     file_name = "prepare-hook.sh"
#   }
# }

# resource "random_password" "ubuntu_vm_password" {
#   length           = 16
#   override_special = "_%@"
#   special          = true
# }

# resource "tls_private_key" "ubuntu_vm_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

# output "ubuntu_vm_password" {
#   value     = random_password.ubuntu_vm_password.result
#   sensitive = true
# }

# output "ubuntu_vm_private_key" {
#   value     = tls_private_key.ubuntu_vm_key.private_key_pem
#   sensitive = true
# }

# resource "local_file" "ubuntu_vm_key" {
#   content  = tls_private_key.ubuntu_vm_key.private_key_pem
#   filename = "${path.root}/.ssh/ubuntu_vm_key.pem"
# }

# output "ubuntu_vm_public_key" {
#   value = tls_private_key.ubuntu_vm_key.public_key_openssh
# }
