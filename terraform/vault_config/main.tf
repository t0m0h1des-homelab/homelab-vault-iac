# KV (Key-Value) シークレットエンジンの有効化
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

# 管理者用ポリシーの作成
resource "vault_policy" "admin_policy" {
  name = "admin-policy"

  policy = <<EOT
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

# サンプルシークレットの登録 (IaCで管理したい固定値など)
resource "vault_kv_secret_v2" "example_creds" {
  mount     = vault_mount.kv.path
  name      = "demo-app/config"
  data_json = jsonencode(
    {
      username = "admin",
      password = "supersecretpassword"
    }
  )
}
