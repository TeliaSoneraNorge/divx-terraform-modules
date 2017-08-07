# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "username" {
  description = "Desired name for the IAM user."
}

variable "keybase" {
  description = "Keybase username. Used to encrypt password and access key."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_iam_user" "main" {
  name          = "${var.username}"
  force_destroy = "true"
}

resource "aws_iam_user_login_profile" "main" {
  user                    = "${aws_iam_user.main.name}"
  pgp_key                 = "keybase:${var.keybase}"
  password_reset_required = "false"
}

resource "aws_iam_access_key" "main" {
  user    = "${aws_iam_user.main.name}"
  pgp_key = "keybase:${var.keybase}"
}

# NOTE: This gives view access on the account the user is registered.
resource "aws_iam_user_policy_attachment" "view_only_policy" {
  user       = "${aws_iam_user.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_user_policy" "password" {
  name   = "manage-own-password"
  user   = "${aws_iam_user.main.name}"
  policy = "${data.aws_iam_policy_document.password.json}"
}

data "aws_iam_policy_document" "password" {
  statement {
    effect = "Allow"

    actions = [
      "iam:ChangePassword",
      "iam:UpdateLoginProfile",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}",
    ]
  }
}

resource "aws_iam_user_policy" "mfa" {
  name   = "manage-own-mfa"
  user   = "${aws_iam_user.main.name}"
  policy = "${data.aws_iam_policy_document.mfa.json}"
}

data "aws_iam_policy_document" "mfa" {
  statement {
    effect = "Allow"

    actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice",
      "iam:DeleteVirtualMFADevice",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/$${aws:username}",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "info" {
  value = <<EOF

Username:          ${var.username}
Password:          ${aws_iam_user_login_profile.main.encrypted_password}
Keybase:           ${var.keybase}
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
  value = "${var.keybase}"
}

output "access_key_id" {
  value = "${aws_iam_access_key.main.id}"
}

output "secret_access_key" {
  value = "${aws_iam_access_key.main.encrypted_secret}"
}
