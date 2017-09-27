storage "dynamodb" {
  ha_enabled    = "false"
  region        = "${region}"
  table         = "${table}"
  redirect_addr = "${redirect}"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
