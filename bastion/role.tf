resource "aws_iam_role" "main" {
  name               = "${var.prefix}-bastion-role"
  assume_role_policy = "${data.aws_iam_policy_document.main.json}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "main" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.prefix}-bastion-profile"
  role = "${aws_iam_role.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-bastion-permissions"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.aws_iam_policy_document.permissions.json}"
}

data "aws_iam_policy_document" "permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = ["arn:aws:s3:::${var.pem_bucket}/${var.pem_path}"]
  }
}
