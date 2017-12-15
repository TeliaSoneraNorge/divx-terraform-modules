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

Likewise, you'll want to specify a version of Terraform and the AWS provider in your `.tf` scripts:

```hcl
terraform {
  required_version = "0.11.1"
}

provider "aws" {
  version = "1.5.0"
  region  = "eu-west-1"
}
```

## Issues

Issues can be added to this repository, and should ideally include a reproducible example. Currently, we have automated 
testing which takes us as far as `terraform plan` on our examples, but some issues only manifest after `apply` 
(which we are currently not doing).

## Contributing

Pull requests are very welcome. New modules should include an `example/` and be added to our Concourse pipeline so it's
tested on [PR](https://github.com/TeliaSoneraNorge/divx-terraform-modules/blob/master/.ci/pipeline.yml#L90-L95) and 
[merge](https://github.com/TeliaSoneraNorge/divx-terraform-modules/blob/master/.ci/pipeline.yml#L219-L262). Your 
`example/` must be able to pass `terraform plan`, so e.g. `data.aws_kms_secret` cannot be included in the example.

Guidelines for new/existing modules:

- Opinionated: strive to export as few variables as possible. If an option should never be touched, don't export it.
- Minimalist: strive to export as few outputs as possible. Most of them are never used.
- Consistent: reuse existing variable/output names.
- Always include:
  - `prefix` variable is used to name resources.
  - `tags` variable (map) propagated to all resources (which can be tagged).
