## iam/developer

An opinionated way of setting up developer roles for projects:

- `ViewOnlyAccess` (attached from the role module).
- Safe with liberal IAM privileges, as the role explicitly denies all IAM actions on the role itself.

Use [iam/policies](../policies/README.md) to attach additional privileges to the role. The
below example would grant the role access to manage `ec2`, `ecs` and `iam` resources that have
the prefix (`example-project-*`) in their name (and write to the terraform state bucket under 
`/example-project/*`).
