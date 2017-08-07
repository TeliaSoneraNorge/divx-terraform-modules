## lambda/function

This module creates a lambda function and takes care of setting up the 
execution role, in addition to zipping/uploading the source code. 
Runtime defaults to node.js 6.10.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "lambda" {
  source      = "github.com/itsdalmo/tf-modules//lambda/function"

  prefix         = "example"
  lambda_policy  = "${data.aws_iam_policy_document.lambda.json}"
  lambda_source  = "${path.root}/../src/"
  lambda_runtime = "nodejs6.10"
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
      "*"
    ]
  }
}

output "lambda_arn" {
  value = "${module.lambda.function_arn}"
}
```
