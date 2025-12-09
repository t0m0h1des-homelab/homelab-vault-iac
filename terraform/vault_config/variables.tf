variable "vault_address" {
  description = "URL of the Vault server (e.g., http://10.0.0.50:8200)"
  type        = string
}

variable "vault_token" {
  description = "Vault Root Token or Admin Token for configuration"
  type        = string
  sensitive   = true
}

variable "kv_mount_path" {
  description = "Path to mount the KV secret engine"
  type        = string
  default     = "secret"
}
