## CloudTrail

This module makes it easier to set up CloudTrail logging for Cross-account roles and is based on the 
[AWS blog post](https://aws.amazon.com/blogs/security/how-to-audit-cross-account-roles-using-aws-cloudtrail-and-amazon-cloudwatch-events/) 
on the subject. However, after some trial and error (see https://github.com/itsdalmo/tf-modules/issues/23) it differs in some ways:

- Sends all log events to the same DynamoDB table, not just events for an assumed role.
- Sets a 90 day TTL on all items inserted into DynamoDB.
- Skips the use of CloudWatch events and uses S3 to simplify log exchange between accounts.

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

module "cloudtrail" {
  source = "github.com/itsdalmo/tf-modules//cloudtrail"
  
  prefix          = "company-cloudtrail"
  read_capacity   = "30"
  write_capacity  = "30"

  source_accounts = [
    "<jump-account-id>",
    "<dev-account-id>",
  ]

  tags {
    environment = "prod"
    terraform   = "True"
  }
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
  include_global_service_events = "true"
  is_multi_region_trail         = "true"
  enable_logging                = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}
```

#### Enable CloudTrail on the dev account:

Same as above.
