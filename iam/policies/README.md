## iam/policies

Module for attaching policies to a role on a per service basis. The policies are scoped down to
grant access to create/update/delete resources with a given prefix, region and account id. Note
that for some services (e.g. `EC2` and `EMR`) which lack fine grained resource control, we scope
the privileges using resource tags.

NOTE: Because we are using count to determine if an `iam_user_name` or `iam_role_name` was provided,
it's not possible to use calculated variables. Meaning that you'll have to 'hardcode' (you can still
use variables) the name of the role and/or user.


## Usage

See example in [iam/developer](../developer/README.md).

