# Vault on Proxmox LXC (IaC)

## 概要

本リポジトリは、**Proxmox LXC** コンテナ上に **HashiCorp Vault** をデプロイするためのIaCコードを含む。

* **Terraform:** Proxmox VE上でのLXCコンテナの払い出し（プロビジョニング）。
* **Ansible:** LXC内へのVaultのインストール、設定ファイルの配置、サービスの起動。

## アーキテクチャ

1.  **プロビジョニング:** TerraformがProxmox APIを叩き、軽量なLXCコンテナ（Debian/Ubuntuベース）を作成する。
2.  **構成管理:** Ansibleが作成されたコンテナへSSH接続し、Vaultバイナリのインストール、`systemd`の設定、Config(HCL)の適用を行う。
3.  **初期化:** （手動手順）オペレーターが `vault operator init` を実行し、Unseal KeyとRoot Tokenを発行する。
4.  **内部設定:** Terraform (Vault Provider) を使用し、初期化で得られたトークンを用いて、ポリシー、Auth Method、Secret Engineなどの論理設定をコードベースで適用する。

## 前提条件

* **Proxmox VE:** 7.x or 8.x or 9.x
* **Nix:** パッケージ管理および環境分離に使用（Flakes有効化済みであること）。
* **Direnv:** ディレクトリごとの環境変数読み込みに使用。

## ディレクトリ構成

本プロジェクトは以下の構成で管理されている。

```
.
├── flake.nix                # 開発環境定義 (Terraform, Ansible, Vault CLI)
├── .envrc                   # direnv設定
├── terraform/
│   ├── pve_vm/           # [Step 1] VMプロビジョニング用
│   │   ├── main.tf
│   │   ├── variables.tf     # 変数定義
│   │   ├── provider.tf      # bpg/proxmox プロバイダ設定
│   │   └── terraform.tfvars # (git対象外) 実環境のパラメータ
│   └── vault_config/     # [Step 3] Vault内部設定用
│       ├── main.tf
│       ├── variables.tf
│       ├── provider.tf      # hashicorp/vault プロバイダ設定
│       └── terraform.tfvars # (git対象外) 接続先とトークン
└── ansible/                 # [Step 2] インストール・起動用
    └── playbook.yml
```

## 使用方法

### 0\. 環境セットアップ (Nix)

本リポジトリでは `flake.nix` により、Terraform (BSLライセンス対応版) や Ansible のバージョンが固定されている。

ディレクトリに移動し、Nix環境をロードする。

```bash
direnv allow
# 初回はNixパッケージのダウンロードが行われる
```

> **Note:** Terraformのライセンス変更に伴い、`flake.nix` 内で `config.allowUnfree = true` を設定し、Unfreeパッケージの利用を許可している。

### 1\. インフラのプロビジョニング (Terraform)

Proxmox上にVMを作成する。

```bash
cd terraform/pve_vm

# 設定ファイルの作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集し、Proxmoxの認証情報やVMスペックを記述する

# 適用
terraform init
terraform apply
```

完了後、出力される `vault_ip`（作成されたVMのIPアドレス）を控えておく。

### 2\. Vaultのインストール (Ansible)

作成されたVMに対して、Vaultのインストールとsystemdによるサービス化を行う。

```bash
cd ../../ansible

# Playbookの実行
# <VAULT_IP> には Step 1 で出力されたIPアドレスを指定する
ansible-playbook -i "<VAULT_IP>," -u root playbook.yml
```

### 3\. Vaultの初期化 (手動)

Vaultはセキュリティ上の理由から、初回起動時に手動での初期化（Unsealキーの生成）が必要となる。

ブラウザで `http://<VAULT_IP>:8200` にアクセスするか、CLIで以下を実行する。

```bash
export VAULT_ADDR='http://<VAULT_IP>:8200'
vault operator init
```

> **重要:** 出力される **Unseal Keys** (5個) と **Initial Root Token** は極めて重要な機密情報であるため、安全な場所に保管すること。

### 4\. Vaultの内部設定 (Terraform)

発行された Root Token を使用し、Vault内部のポリシーやシークレットエンジンを設定する。

```bash
cd ../terraform/vault_config

# 設定ファイルの作成
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` に、Step 1のIPアドレスと、Step 3で取得したトークンを記載する。

```hcl
vault_address = "http://<VAULT_IP>:8200"
vault_token   = "<ROOT_TOKEN>"
```

適用を実行する。

```bash
terraform init
terraform apply
```

## 技術的メモ

* **メモリロック (mlock):** Proxmox LXCなどのコンテナ環境では `mlock` システムコールが制限される場合があるため、Ansible設定にて `disable_mlock = true` を適用している。
* **ストレージ:** デフォルト構成ではファイルシステム (`file`) をバックエンドに使用している。可用性が求められる場合はRaftストレージへの変更を検討すること。
