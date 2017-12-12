## iam/role

Module for creating an IAM role with a trusted relationship to users in a trusted account, 
which can be used to grant cross-account access to roles: 

- By default, the role grants `ViewOnlyAccess` access.
- `sts:AssumeRole` is granted to individual users in the trusted account.

Granting access to the role on a per-user basis ensures that the `user-account` is only responsible
for authentication, while the `dev-account` (where the role is created) is responsible for authorization.

Users will still have to be given a policy on the `user-account` which
grants them access to assume roles in remote accounts (the `dev-account`).
The [iam/user](../user/README.md) module solves this by attaching an inline
policy to all users, giving them privileges to assume any role in remote 
accounts.

