## iam/policy

These policies attempt to give users freedom while being less brittle than a wildcard privilege. This
is done by granting `*` access on resources, but limiting the roles scope to resources with a given:

- Prefix
- Region
- Account Id

See example in [iam/developer](../developer/README.md).

Note that these restrictions are used when possible, and that some services require different constraints:

- `ec2`: Lacks fine-grained access control. The best option is to restrict a roles privileges to a VPC.
- `s3`: The ARN does not take a region.
- `apigateway`: The ARN for a REST API does not include the name (so prefix is not used).

