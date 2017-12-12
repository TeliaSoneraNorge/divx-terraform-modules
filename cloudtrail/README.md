## CloudTrail

This module makes it easier to set up CloudTrail logging for Cross-account roles and is based on the 
[AWS blog post](https://aws.amazon.com/blogs/security/how-to-audit-cross-account-roles-using-aws-cloudtrail-and-amazon-cloudwatch-events/) 
on the subject. However, after some trial and error (see https://github.com/TeliaSoneraNorge/divx-terraform-modules/issues/23) it differs in some ways:

- Sends all log events to the same DynamoDB table, not just events for an assumed role.
- Sets a 90 day TTL on all items inserted into DynamoDB.
- Skips the use of CloudWatch events and uses S3 to simplify log exchange between accounts.

Note that for `AssumeRole` events, the `accessKeyId` found in DynamoDB is the temporary key returned from the STS call
and **not** the users `accessKeyId`.

