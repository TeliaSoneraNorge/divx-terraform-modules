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

To decrypt the Keybase encrypted password/secret you must wrap them in the following:

```
-----BEGIN PGP MESSAGE-----
Version: Keybase OpenPGP v2.0.73
Comment: https://keybase.io/crypto

<encrypted-string>
-----END PGP MESSAGE-----
```
