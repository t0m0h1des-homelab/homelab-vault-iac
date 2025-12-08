# Vault on Proxmox LXC (IaC)

## 概要

本リポジトリは、**Proxmox LXC** コンテナ上に **HashiCorp Vault** をデプロイするためのIaCコードを含む。

* **Terraform:** Proxmox VE上でのLXCコンテナの払い出し（プロビジョニング）。
* **Ansible:** LXC内へのVaultのインストール、設定ファイルの配置、サービスの起動。

## アーキテクチャ

1.  **プロビジョニング:** TerraformがProxmox APIを叩き、軽量なLXCコンテナ（Debian/Ubuntuベース）を作成する。
2.  **構成管理:** Ansibleが作成されたコンテナへSSH接続し、Vaultバイナリのインストール、`systemd`の設定、Config(HCL)の適用を行う。
3.  **初期化:** （手動手順）オペレーターが `vault operator init` を実行し、Unseal KeyとRoot Tokenを発行する。
