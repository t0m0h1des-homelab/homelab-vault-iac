# Vault構築・K8s連携 検証手順書

## 1\. Vaultサーバーの初期化・トークン発行

Ansible等でインストール済みだが未初期化（または再初期化が必要）な状態を想定し、Vaultサーバー上で以下を実行する。

### 1-1. データのリセット（再初期化の場合のみ）

すでに `vault status` で `Initialized: true` となっており、Root Tokenが不明な場合はデータを削除してリセットする。

```bash
# Vault停止
systemctl stop vault

# データ削除 (設定ファイルの path に合わせる。例: /opt/vault/data)
rm -rf /opt/vault/data/*

# Vault起動
systemctl start vault
```

### 1-2. 初期化とUnseal（封印解除）

Vaultサーバーにて環境変数を設定し、初期化を行う。

```bash
# プロトコル指定 (http)
export VAULT_ADDR='http://127.0.0.1:8200'

# 初期化 (出力される Unseal Key 1-5 と Initial Root Token を必ず控えること)
vault operator init

# 封印解除 (3回実行し、それぞれ異なる Unseal Key を入力する)
vault operator unseal
vault operator unseal
vault operator unseal
```

### 1-3. Terraform用トークンの発行

Root Tokenでログインし、Terraform実行用のトークンを発行する。

```bash
# Root Tokenでログイン
vault login

# 有効期限24時間のトークン作成 (ポリシーは適宜調整、検証用としてrootを使用)
vault token create -policy=root -period=24h

# 出力された token (hvs.xxxxx...) を控える
```

-----

## 2\. K8s側の準備 (認証用情報の取得)

K8sクラスタに対し、VaultがAPIへアクセスするためのServiceAccount (SA) を作成し、情報を取得する。

### 2-1. ServiceAccount作成

以下のYAMLをK8sクラスタに適用する。

**`vault-auth-sa.yaml`**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
```

```bash
kubectl apply -f vault-auth-sa.yaml
```

### 2-2. 変数値の抽出

Terraformへ渡すための変数を取得する。

1.  **K8s Host**: クラスタのAPIサーバーURL (例: `https://192.168.1.10:6443`)
2.  **CA Cert**:
    ```bash
    kubectl get secret vault-auth-token -n kube-system -o jsonpath='{.data.ca\.crt}' | base64 --decode
    ```
3.  **Reviewer Token**:
    ```bash
    kubectl get secret vault-auth-token -n kube-system -o jsonpath='{.data.token}' | base64 --decode
    ```

-----

## 3\. Terraformによる構成管理

作業用PCにてTerraformを実行し、Vaultの設定を行う。

### 3-1. ファイル作成

以下の4ファイルを作成する。

**`provider.tf`**

```hcl
terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "4.2.0"
    }
  }
}
provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}
```

**`variables.tf`**

```hcl
variable "vault_address" {}
variable "vault_token" { sensitive = true }
variable "k8s_host" {}
variable "k8s_ca_cert" {}
variable "vault_reviewer_token" { sensitive = true }
```

**`main.tf`**

```hcl
# 1. Secret Engine
resource "vault_mount" "kv" {
  path = "secret"
  type = "kv"
  options = { version = "2" }
}

resource "vault_kv_secret_v2" "example_creds" {
  mount     = vault_mount.kv.path
  name      = "demo-app/config"
  data_json = jsonencode({ username = "db_user", password = "super-secure-password" })
}

# 2. Policy
resource "vault_policy" "app_read_policy" {
  name = "demo-app-read"
  policy = <<EOT
path "secret/data/demo-app/config" { capabilities = ["read"] }
EOT
}

# 3. Auth Method (Kubernetes)
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.k8s_host
  kubernetes_ca_cert = var.k8s_ca_cert
  token_reviewer_jwt = var.vault_reviewer_token
  disable_iss_validation = true
}

# 4. Role
resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "demo-app-role"
  bound_service_account_names      = ["demo-app-sa"]
  bound_service_account_namespaces = ["default"]
  token_policies                   = [vault_policy.app_read_policy.name]
  token_ttl                        = 3600
}
```

**`terraform.tfvars`** (これに実際の値を記述)

```hcl
vault_address = "http://192.168.x.x:8200" # VaultサーバーIP
vault_token   = "hvs.xxxxxx"              # 手順1-3で発行したトークン

k8s_host             = "https://192.168.x.x:6443"
vault_reviewer_token = "eyJhbGci..."      # 手順2-2で取得したトークン

# ヒアドキュメントでCA証明書を貼り付け
k8s_ca_cert = <<EOT
-----BEGIN CERTIFICATE-----
... (証明書の中身) ...
-----END CERTIFICATE-----
EOT
```

### 3-2. 適用

```bash
terraform init
terraform apply
```

-----

## 4\. 動作検証

K8sクラスタ上で実際にPodを起動し、シークレットが注入されるか確認する。

### 4-1. Vault Agent Injectorのインストール

まだ導入していない場合、Helmでインストールする。外部Vaultのアドレス指定が必須である。

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
  --set "injector.externalVaultAddr=http://<VAULT_SERVER_IP>:8200" \
  --set "server.enabled=false"
```

### 4-2. テスト用Podのデプロイ

Terraformで許可したSA (`demo-app-sa`) とRoleを使用するPodを作成する。

**`test-pod.yaml`**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app-sa
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: demo-app
  namespace: default
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "demo-app-role"
    vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/demo-app/config"
    vault.hashicorp.com/agent-inject-template-config.txt: |
      {{- with secret "secret/data/demo-app/config" -}}
      User: {{ .Data.data.username }}
      Pass: {{ .Data.data.password }}
      {{- end -}}
spec:
  serviceAccountName: demo-app-sa
  containers:
    - name: app
      image: alpine
      command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
```

```bash
kubectl apply -f test-pod.yaml
```

### 4-3. 結果確認

Pod起動後、ファイルの中身を確認する。

```bash
# PodがReadyになるのを待つ
kubectl wait --for=condition=Ready pod/demo-app

# ファイル確認
kubectl exec demo-app -- cat /vault/secrets/config.txt
```

以下の出力が得られれば成功である。

```text
User: db_user
Pass: super-secure-password
```
