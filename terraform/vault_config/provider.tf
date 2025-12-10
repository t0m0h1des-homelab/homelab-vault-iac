terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "4.2.0"
    }
  }
}

provider "vault" {
  address = var.vault_address # 例: http://192.168.1.50:8200
  token   = var.vault_token   # Root Tokenなど
}
