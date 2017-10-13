# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ec2" {
  count  = "${contains(var.services, "ec2") == "true" ? 1 : 0}"
  name   = "${var.prefix}-ec2-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.ec2.json}"
}

data "aws_iam_policy_document" "ec2" {
  # NOTE: The instance profiles which can be passed is limited to the prefix by `iam:PassRole`.
  statement {
    effect = "Allow"

    not_actions = [
      "ec2:CreateSecurityGroup",
      "ec2:CreateVolume",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "ec2:RunInstances",
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:MonitorInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  # NOTE: Many EC2 actions do not support resource level permissions.
  statement {
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeTags",
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:MonitorInstances",
      "ec2:CreateSecurityGroup",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLikeIfExists"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "StringLikeIfExists"
      variable = "aws:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DeleteTags",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "ForAllValues:StringNotEquals"
      variable = "aws:TagKeys"
      values   = ["Name"]
    }
  }

  /*
  NOTE: ec2:RunInstances has differing levels of resource control:
  1. RequestTag: Instance/volume is tagged at launch.
  2. ARN: key-pair is the only resource that can be limited by resource name.
  3. ResourceTag (including default): Special case for Subnet, in case users want to launch in the default vpc.
  4. ResourceTag: Only for snapshot, as users should not be allowed to launch a snapshot that is not guaranteed to be their own.
  5. ResourceTag (if exists): Certain resources don't have a Name tag when created by AWS or launched in the console.
  6. No restriction: Some resources cannot be constrained.
  */
  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:instance/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:volume/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "aws:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:key-pair/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:subnet/*",
    ]

    condition = {
      test = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values = ["default-subnet-*", "${coalesce(var.resources, "${var.prefix}-*")}"]
    }

  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:snapshot/*",
    ]

    condition = {
      test = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}::image/*",                                # Most images don't have a Name tag and don't support account_id.
      "arn:aws:ec2:${var.region}:${var.account_id}:network-interface/*",   # All network interfaces created by AWS lack a Name tag.
      "arn:aws:ec2:${var.region}:${var.account_id}:security-group/*",      # Security groups don't have a Name tag when created via Console.
    ]

    condition = {
      test = "StringLikeIfExists"
      variable = "ec2:ResourceTag/Name"
      values = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:elastic-gpu/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:placement-group/*",
    ]
  }
}
