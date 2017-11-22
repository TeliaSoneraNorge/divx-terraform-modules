# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "username of machine user"
}

variable "keybase" {
  description = "Keybase username of user that can unencrypy the encrypted secret_access_key from the logs"
}

variable "policy" {
  description = "policy that will be assigned to the machine user"
}


# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_user" "machine-user" {
  name          = "${var.prefix}"
  force_destroy = "true"
}

resource "aws_iam_access_key" "machine-user-key" {
  user    = "${aws_iam_user.machine-user.name}"
  pgp_key = "keybase:${var.keybase}"
}

resource "aws_iam_user_policy" "machine-user-policy" {
  name = "${var.prefix}-user-policy"
  user = "${aws_iam_user.machine-user.name}"
  policy = "${var.policy}"
}



# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "${var.prefix}_access_key_id" {
  value = "${aws_iam_access_key.machine-user-key.id}"
}

output "${var.prefix}_secret_access_key" {
  value = "${aws_iam_access_key.machine-user-key.encrypted_secret}"
}