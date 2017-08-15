## iam\_user

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "user" {
  source   = "github.com/itsdalmo/tf-modules//iam/user"

  username = "firstname.lastname"
  keybase  = "itsdalmo"
}

output "info" {
  value = "${module.user.info}"
}
```

## User steps

1. Decrypt password/secret access key using Keybase.

```
-----BEGIN PGP MESSAGE-----
Version: Keybase OpenPGP v2.0.73
Comment: https://keybase.io/crypto

<encrypted-password-OR-secret-key>
-----END PGP MESSAGE-----
```

2. Enable MFA in the console after logging in. (Req. to assume roles)
3. Get `role_url` and assume any roles you have privileges to assume.
4. Set up AWS credentials as follows:

```
[example-user]
aws_access_key_id = <key-id>
aws_secret_access_key = <secret-key>

[example-role]
role_arn = <role-arn>
source_profile = example-user
```

