resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

# テスト用シークレット (パス: secret/data/demo-app/config)
resource "vault_kv_secret_v2" "example_creds" {
  mount     = vault_mount.kv.path
  name      = "demo-app/config"
  data_json = jsonencode(
    {
      username = "db_user",
      password = "super-secure-password-from-vault"
    }
  )
}

resource "vault_policy" "app_read_policy" {
  name = "demo-app-read"

  policy = <<EOT
path "secret/data/demo-app/config" {
  capabilities = ["read"]
}
EOT
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

# 外部VaultがK8s APIと通信するための設定
resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.k8s_host
  kubernetes_ca_cert = file(var.k8s_ca_cert)
  token_reviewer_jwt = var.vault_reviewer_token

  # 自己署名証明書などで検証エラーが出る場合は一旦 true に
  disable_iss_validation = true
}

resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "demo-app-role"

  # 紐付けるK8s側のService Account情報
  bound_service_account_names      = ["demo-app-sa"]
  bound_service_account_namespaces = ["default"]

  # 適用するポリシー
  token_policies                   = [vault_policy.app_read_policy.name]
  token_ttl                        = 3600
}
