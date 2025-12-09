resource "proxmox_virtual_environment_vm" "vault" {
  name      = var.vm_name
  node_name = var.target_node

  clone {
    vm_id = var.template_id
  }

  agent { enabled = true }

  cpu {
    cores = var.vm_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = 20
    file_format  = "raw"
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.vm_ipv4_address # 例: 192.168.1.50/24
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }

    user_account {
      username = "root"
      keys     = [var.ssh_public_key]
    }
  }

  network_device {
    bridge = "vmbr0"
  }
}

output "vault_ip" {
  value = element(split("/", var.vm_ipv4_address), 0)
}
