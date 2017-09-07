storage "dynamodb" {
  ha_enabled = "true"
  region     = "${region}"
  table      = "${table}"
}

listener "tcp" {
  address = "127.0.0.1:8200"
}
