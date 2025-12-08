# Vault on Proxmox LXC (IaC)

## Overview

This repository contains Infrastructure as Code (IaC) to deploy **HashiCorp Vault** on a **Proxmox LXC** container.

* **Terraform:** Provisions the LXC container on Proxmox VE.
* **Ansible:** Installs, configures, and bootstraps the Vault service within the LXC.

## Architecture

1.  **Provisioning:** Terraform communicates with the Proxmox API to create a lightweight LXC container (Debian/Ubuntu based).
2.  **Configuration:** Ansible connects via SSH to the new container to install the Vault binary, configure `systemd`, and apply the configuration (HCL).
3.  **Initialization:** (Manual Step) Operator runs `vault operator init` to generate Unseal Keys and Root Token.

