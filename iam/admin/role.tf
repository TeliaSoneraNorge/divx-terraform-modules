# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix added to the role name."
}

variable "trusted_account" {
  description = "ID of the account which is trusted with access to assume this role."
}

variable "users" {
  type        = "list"
  description = "List of users in the trusted account which will be allowed to assume this role."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
module "role" {
  source = "../role"

  prefix          = "${var.prefix}-admin"
  trusted_account = "${var.account_id}"
  users           = "${var.users}"
}

resource "aws_iam_role_policy_attachment" "admin" {
  role       = "${module.role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "name" {
  value = "${module.role.name}"
}

output "arn" {
  value = "${module.role.arn}"
}

output "url" {
  value = "${module.role.url}"
}
