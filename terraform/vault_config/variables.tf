# --- Provider用 (Vaultへの接続) ---
variable "vault_address" {
  description = "Vaultサーバーのアドレス (例: http://192.168.1.50:8200)"
  type        = string
}

variable "vault_token" {
  description = "Terraform実行用のVaultトークン (Root Tokenなど)"
  type        = string
  sensitive   = true
}

# --- Main用 (K8s認証連携設定) ---
variable "k8s_host" {
  description = "Vaultから見たK8s APIのURL (例: https://192.168.1.10:6443)"
  type        = string
}

variable "k8s_ca_cert" {
  description = "K8sのCA証明書 (PEM形式)"
  type        = string
}

variable "vault_reviewer_token" {
  description = "VaultがK8s APIを叩くためのServiceAccountトークン"
  type        = string
  sensitive   = true
}
