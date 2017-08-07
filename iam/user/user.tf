# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "username" {
  description = "Desired name for the IAM user."
}

variable "keybase_user" {
  description = "Keybase username. Used to encrypt password and access key."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_user" "main" {
  name = "${var.username}"
  force_destroy = "true"
}

resource "aws_iam_user_login_profile" "main" {
  user    = "${aws_iam_user.main.name}"
  pgp_key = "keybase:${var.keybase_user}"
}

resource "aws_iam_access_key" "main" {
  user    = "${aws_iam_user.main.name}"
  pgp_key = "keybase:${var.keybase_user}"
}

# NOTE: This gives view access on the account the user is registered.
resource "aws_iam_user_policy_attachment" "view_only_policy" {
  user       = "${aws_iam_user.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# resource "aws_iam_user_policy" "main" {
#   name = "basic-user-privileges"
#   user = "${aws_iam_user.main.name}"
#   policy = "${data.aws_iam_policy_document.main.json}"
# }

# data "aws_iam_policy_document" "main" {
#   # TODO: Add MFA/password/key management.
# }

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "info" {
  value = <<EOF

Username:          ${var.username}
Password:          ${aws_iam_user_login_profile.main.encrypted_password}
Keybase:           ${var.keybase_user}
Access Key Id:     ${aws_iam_access_key.main.id}
Secret Access Key: ${aws_iam_access_key.main.encrypted_secret}

EOF
}

output "name" {
  value = "${var.username}"
}

output "password" {
  value = "${aws_iam_user_login_profile.main.encrypted_password}"
}

output "keybase" {
  value = "${var.keybase_user}"
}

output "access_key_id" {
  value = "${aws_iam_access_key.main.id}"
}

output "secret_access_key" {
  value = "${aws_iam_access_key.main.encrypted_secret}"
}
