## terraform/tags

A utility module for convenient handling of tags. Its convenient because
it allows passing tags in the same format to all modules, without special
cases like tags for autoscaling groups (propagating the tags is a good
practice, and so it is always enabled in this module).

Outputs:
- standard: just the merged maps.
- autoscaling: a list of maps with key/value as provided, and `propagate_at_launch = true`.

Example from the `ec2/asg` module:

```hcl
variable "tags" {
  description = "A map of tags (key-value pairs)."
  type        = "map"
  default     = {}
}

module "tags" {
  source = "github.com/itsdalmo/tf-modules//terraform/tags"
  passed = "${var.tags}"
 
  tags {
    Name      = "${var.prefix}"
    terraform = "true"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  tags = "${module.tags.standard}"
}

resource "aws_autoscaling_group" "main" {
  name                 = "${aws_launch_configuration.main.name}"
  desired_capacity     = "${var.instance_count}"
  min_size             = "${var.instance_count}"
  max_size             = "${var.instance_count + 1}"
  launch_configuration = "${aws_launch_configuration.main.name}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]

  tags = ["${module.tags.autoscaling}"]

  lifecycle {
    create_before_destroy = true
  }
}

```

NOTE: A side-effect of using `null_data_source` is that `"true"` gets converted to
`1` in the output. This is a known issue which is being tracked [here](https://github.com/hashicorp/terraform/issues/13512).
