provider "aws" {
  region = "eu-west-1"
}

module "lambda" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//lambda/function"

  prefix      = "example"
  policy      = "${data.aws_iam_policy_document.lambda.json}"
  source_code = "${path.root}/../src/"
  runtime     = "nodejs6.10"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "*",
    ]
  }
}

output "lambda_arn" {
  value = "${module.lambda.function_arn}"
}