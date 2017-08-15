# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "username" {
  description = "Desired name for the IAM user."
}

variable "keybase" {
  description = "Keybase username. Used to encrypt password and access key."
}

variable "ssh_key" {
  description = "Public SSH key for the user. Exported for use in other modules."
  default     = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_iam_account_alias" "current" {}

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
      "iam:EnableMFADevice",
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
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/$${aws:username}",
    ]
  }
}

resource "aws_iam_user_policy" "assume" {
  name   = "assume-cross-account-role"
  user   = "${aws_iam_user.main.name}"
  policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    not_resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "instructions" {
  value = <<EOF

1. Decrypt your password and access key on keybase:

-----BEGIN PGP MESSAGE-----

${aws_iam_user_login_profile.main.encrypted_password}
-----END PGP MESSAGE-----

2. Log into the console (remember to enable MFA):
URL:      https://${data.aws_iam_account_alias.current.account_alias}.signin.aws.amazon.com/console
Username: ${var.username}
Password: <your-decrypted-password>

3. Decrypt your secret access key:

-----BEGIN PGP MESSAGE-----

${aws_iam_access_key.main.encrypted_secret}
-----END PGP MESSAGE-----

4. Add a profile to ~/.aws/credentials:

[account-user]
aws_access_key_id = ${aws_iam_access_key.main.id}
aws_secret_access_key = <your-decrypted-secret-access-key>

5. Add roles to your ~/.aws/credentials. Example:

[account-developer]
role_arn = <account-role-arn>
source_profile = account-user

EOF
}

output "name" {
  value = "${var.username}"
}

output "password" {
  value = "${aws_iam_user_login_profile.main.encrypted_password}"
}

output "ssh_key" {
  value = "${var.ssh_key}"
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
