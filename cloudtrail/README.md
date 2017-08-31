## CloudTrail

This module makes it easier to set up CloudTrail logging for Cross-account roles and is based on the 
[AWS blog post](https://aws.amazon.com/blogs/security/how-to-audit-cross-account-roles-using-aws-cloudtrail-and-amazon-cloudwatch-events/) 
on the subject. The module differs in a few ways:

- It is meant to send all log events to the same DynamoDB table, not just events for an assumed role.
- Uses CloudWatch subscription filters instead of SNS events to invoke Lambda for `assumeRole` events.
- Meant to be deployed to a logging account, with logs being pushed from remote accounts.
- Sets a 90 day TTL on all items inserted into DynamoDB.

Note that for `AssumeRole` events, the `accessKeyId` found in DynamoDB is the temporary key returned from the STS call
and **not** the users `accessKeyId`.

### Usage

To deploy to a logging account, with users assuming roles in a jump account and doing work on a dev account:

#### Set up the infrastructure on the logging account:

```hcl
provider "aws" {
  profile = "log-admin"
  region  = "eu-west-1"
}

module "table" {
  source = "github.com/itsdalmo/tf-modules//cloudtrail/dynamodb"

  prefix      = "central-cloudtrail-table"
  environment = "prod"
}

module "assume_role_trail" {
  source = "github.com/itsdalmo/tf-modules//cloudtrail"

  prefix            = "jump-user-assume-role"
  environment       = "prod"
  trail_account     = "<jump-account-id>"
  dynamodb_name     = "${module.table.dynamodb_name}"
  dynamodb_arn      = "${module.table.dynamodb_arn}"
  region            = "eu-west-1"
  cloudwatch_filter = <<EOF
{ ($.userIdentity.type = "IAMUser") && ($.eventSource = "sts.amazonaws.com") && ($.eventName = "AssumeRole") }
EOF
}

module "dev_account_trail" {
  source = "github.com/itsdalmo/tf-modules//cloudtrail"

  prefix            = "dev-account"
  environment       = "prod"
  trail_account     = "<dev-account-id>"
  dynamodb_name     = "${module.table.dynamodb_name}"
  dynamodb_arn      = "${module.table.dynamodb_arn}"
  region            = "eu-west-1"
  cloudwatch_filter = ""
}
```

#### Enable CloudTrail on the jump account:

```hcl
provider "aws" {
  profile = "jump-admin"
  region  = "eu-west-1"
}

resource "aws_cloudtrail" "users" {
  name                          = "jump-user-assume-role-trail"
  s3_bucket_name                = "${module.assume_role_trail.bucket_name}"
  cloud_watch_logs_group_arn    = "${module.assume_role_trail.log_group_arn}"
  cloud_watch_logs_role_arn     = "${module.assume_role_trail.role_arn}"
  include_global_service_events = "true"
  is_multi_region_trail         = "true"
  enable_logging                = "true"

  tags {
    environment = "prod"
    terraform   = "true"
  }
}
```

#### Enable CloudTrail on the dev account:

Same as above.
