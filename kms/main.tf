# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "${var.description}"
  tags                    = "${var.tags}"
  is_enabled              = "true"
  deletion_window_in_days = 30
  enable_key_rotation     = "false"
  key_usage               = "ENCRYPT_DECRYPT"
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.prefix}"
  target_key_id = "${aws_kms_key.main.key_id}"
}
