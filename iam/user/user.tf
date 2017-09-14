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

resource "aws_iam_user_policy" "read_policies" {
  name   = "inspect-own-policies"
  user   = "${aws_iam_user.main.name}"
  policy = "${data.aws_iam_policy_document.read_policies.json}"
}

data "aws_iam_policy_document" "read_policies" {
  statement {
    effect = "Allow"

    actions = [
      "iam:GetUserPolicy",
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:GetPolicyVersion",
    ]

    resources = [
      "*",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "instructions" {
  value = <<EOF

1. Decrypt your password using Keybase.io:

echo ${aws_iam_user_login_profile.main.encrypted_password} | base64 --decode | keybase pgp decrypt

2. Log into the console:

  URL:      https://${data.aws_iam_account_alias.current.account_alias}.signin.aws.amazon.com/console
  Username: ${var.username}
  Password: <your-decrypted-password>

3. Enable (virtual) MFA using the console:

  https://console.aws.amazon.com/iam/home?region=global#/users/${var.username}?section=security_credentials

4. Decrypt your secret access key:

echo ${aws_iam_access_key.main.encrypted_secret} | base64 --decode | keybase pgp decrypt

5. Install (requires homebrew) and add a profile to vaulted:

  $ brew install vaulted
  $ vaulted add <profile-name>

  Follow the instructions and add your keys and MFA device:

  Access Key ID: ${aws_iam_access_key.main.id}
  Secret Access Key: <your-decrypted-secret-access-key>
  MFA: arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/${var.username}

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
