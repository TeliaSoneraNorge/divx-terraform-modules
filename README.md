## Terraform modules

Reusable terraform modules for AWS. Opinionated and minimalistic, as far as possible.

## Usage

Each subdirectory of this repository contains one or more modules. Each module should have a `README.md` with a usage example.

To use a module, simply reference this repository as the source use `//<path>` to the subdirectory of a module:

```hcl
module "something" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion"
}
```

Because the repsitory and all modules are subject to changes, you'll want to reference a [release](https://github.com/TeliaSoneraNorge/divx-terraform-modules/releases) in the source:

```hcl
module "something" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion?ref=0.1.0"
}
```

Likewise, you'll want to specify a version of the AWS provider in your `.tf` scripts:

```hcl
provider "aws" {
  version = "1.1.0"
  region  = "eu-west-1"
}
```
