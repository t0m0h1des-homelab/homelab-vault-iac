terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.66.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = "${var.pve_user}!${var.pve_token_id}=${var.pve_token_secret}"
  insecure  = true
  ssh {
    agent = true
  }
}
