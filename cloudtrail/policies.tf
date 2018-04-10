data "aws_iam_policy_document" "bucket" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = ["arn:aws:s3:::${var.prefix}-cloudtrail-logs"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${formatlist("arn:aws:s3:::${var.prefix}-cloudtrail-logs/AWSLogs/%s/*", var.source_accounts)}",
    ]

    condition = {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type = "AWS"

      # TODO we might want to lock this down further?
      identifiers = [
        "${formatlist("arn:aws:iam::%s:root", var.source_accounts)}",
      ]
    }

    actions = [
      "s3:GetObjectAcl",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObject",
    ]

    resources = [
      "${formatlist("arn:aws:s3:::${var.prefix}-cloudtrail-logs/AWSLogs/%s/*", var.source_accounts)}",
    ]
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*",
    ]

    resources = ["${aws_dynamodb_table.main.arn}"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.main.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
}
