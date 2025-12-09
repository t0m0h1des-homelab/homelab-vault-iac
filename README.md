# Vault on Proxmox LXC (IaC)

## Overview

This repository contains Infrastructure as Code (IaC) to deploy **HashiCorp Vault** on a **Proxmox LXC** container.

* **Terraform:** Provisions the LXC container on Proxmox VE.
* **Ansible:** Installs Vault, configures systemd services, and applies configuration files within the LXC.

## Architecture

1.  **Provisioning:** Terraform communicates with the Proxmox API to create a lightweight LXC container (Debian/Ubuntu based).
2.  **Configuration Management:** Ansible connects via SSH to the created container to install the Vault binary, configure `systemd`, and apply the Config (HCL).
3.  **Initialization:** (Manual Step) The operator runs `vault operator init` to generate Unseal Keys and the Root Token.
4.  **Internal Configuration:** Terraform (Vault Provider) applies logical configurations—such as policies, Auth Methods, and Secret Engines—using the token obtained from initialization.

## Prerequisites

* **Proxmox VE:** 7.x, 8.x, or 9.x
* **Nix:** Used for package management and environment isolation (Flakes must be enabled).
* **Direnv:** Used to load environment variables per directory.

## Directory Structure

The project is managed with the following structure:

```text
.
├── flake.nix                # Dev environment definition (Terraform, Ansible, Vault CLI)
├── .envrc                   # direnv configuration
├── terraform/
│   ├── pve_vm/              # [Step 1] VM Provisioning
│   │   ├── main.tf
│   │   ├── variables.tf     # Variable definitions
│   │   ├── provider.tf      # bpg/proxmox provider settings
│   │   └── terraform.tfvars # (ignored by git) Real environment parameters
│   └── vault_config/        # [Step 3] Vault Internal Configuration
│       ├── main.tf
│       ├── variables.tf
│       ├── provider.tf      # hashicorp/vault provider settings
│       └── terraform.tfvars # (ignored by git) Connection info and Token
└── ansible/                 # [Step 2] Installation & Startup
    └── playbook.yml
```

## Usage

### 0\. Environment Setup (Nix)

This repository uses `flake.nix` to pin specific versions of Terraform (BSL license compatible) and Ansible.

Navigate to the directory and load the Nix environment.

```bash
direnv allow
# Nix packages will be downloaded on the first run
```

> **Note:** Due to Terraform's license change, `config.allowUnfree = true` is set in `flake.nix` to allow the use of unfree packages.

### 1\. Infrastructure Provisioning (Terraform)

Create the VM on Proxmox.

```bash
cd terraform/pve_vm

# Create configuration file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to set Proxmox credentials and VM specs

# Apply
terraform init
terraform apply
```

After completion, note the outputted `vault_ip` (the IP address of the created VM).

### 2\. Vault Installation (Ansible)

Install Vault and configure the systemd service on the created VM.

```bash
cd ../../ansible

# Run Playbook
# Replace <VAULT_IP> with the IP address output from Step 1
ansible-playbook -i "<VAULT_IP>," -u root playbook.yml
```

### 3\. Vault Initialization (Manual)

For security reasons, Vault requires manual initialization (generating Unseal keys) upon first startup.

Access `http://<VAULT_IP>:8200` via a browser or run the following CLI commands:

```bash
export VAULT_ADDR='http://<VAULT_IP>:8200'
vault operator init
```

> **Important:** The outputted **Unseal Keys** (5 keys) and **Initial Root Token** are critical secrets. Store them securely.

### 4\. Vault Internal Configuration (Terraform)

Use the generated Root Token to configure internal Vault policies and secret engines.

```bash
cd ../terraform/vault_config

# Create configuration file
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with the IP from Step 1 and the Token from Step 3.

```hcl
vault_address = "http://<VAULT_IP>:8200"
vault_token   = "<ROOT_TOKEN>"
```

Execute the apply.

```bash
terraform init
terraform apply
```

## Technical Notes

  * **Memory Lock (mlock):** Since `mlock` system calls are often restricted in container environments like Proxmox LXC, `disable_mlock = true` is applied in the Ansible configuration.
  * **Storage:** The default configuration uses the filesystem (`file`) backend. Consider switching to Raft storage if high availability is required.
