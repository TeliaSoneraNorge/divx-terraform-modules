storage "dynamodb" {
  ha_enabled = "true"
  region     = "${region}"
  table      = "${table}"
}

listener "tcp" {
  address = "0.0.0.0:8200"
}
