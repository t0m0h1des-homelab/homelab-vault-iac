variable "pve_endpoint" {
  description = "Proxmox API Endpoint (e.g., https://192.168.1.10:8006/)"
  type        = string
}

variable "pve_user" {
  description = "Proxmox User (e.g., terraform-admin@pve)"
  type        = string
}

variable "pve_token_id" {
  description = "Proxmox API Token ID"
  type        = string
}

variable "pve_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

# --- VM Configuration ---

variable "target_node" {
  description = "Target Proxmox Node Name"
  type        = string
  default     = "pve1"
}

variable "template_id" {
  description = "ID of the VM template to clone"
  type        = number
  default     = 9000
}

variable "vm_name" {
  description = "The name of the Vault VM"
  type        = string
  default     = "vault-server"
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory size in MB"
  type        = number
  default     = 2048
}

variable "vm_disk_storage" {
  description = "Storage ID for the OS disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

# --- Network & Access ---

variable "vm_ipv4_address" {
  description = "Static IPv4 address in CIDR notation"
  type        = string
  default     = "192.168.1.50/24"
}

variable "vm_gateway" {
  description = "Gateway IP address"
  type        = string
  default     = "192.168.1.1"
}

variable "ssh_public_key" {
  description = "SSH Public Key for VM access (root)"
  type        = string
}
