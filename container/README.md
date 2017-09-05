## Container

Set up an ECS cluster and register services with ease. The modules set up the following:

#### container/cluster

- Autoscaling group/launch configuration.
- CoreOS instances with ECS agent running.
- A security group for the cluster (with all egress).
- CloudWatch log group.
- IAM role/instance profile with appropriate privileges.

#### container/service

- Usable with either an ALB or a classic ELB (to be tested).
- Optional: Creates the ALB target group (when used with an ALB).
- Sets up and enables logging for the task.
- Creates IAM roles for the ECS service and for a specific task/containers.
- Takes care of opening ingress on the appropriate ports from the load balancer (ALB or classic ELB) to the cluster.

## Usage

```hcl
variable "prefix" {
  default = "ecs-test"
}

variable "vpc_id" {
  default = "vpc-12345678"
}

variable "subnets" {
  default = ["subnet-12345678", "subnet-23456789"]
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

// ALB w/ingress and listener rule
module "alb" {
  source = "github.com/itsdalmo/tf-modules//ec2/alb"

  prefix      = "${var.prefix}"
  environment = "dev"
  internal    = "false"
  vpc_id      = "${var.vpc_id}"
  subnet_ids  = ["${var.subnets}"]
}

// Cluster
module "cluster" {
  source = "github.com/itsdalmo/tf-modules//container/cluster"

  prefix      = "${var.prefix}"
  environment = "dev"
  vpc_id      = "${var.vpc_id}"
  subnet_ids  = ["${var.subnets}"]
}

// Service
module "service" {
  source = "github.com/itsdalmo/tf-modules//container/service"

  prefix             = "${var.prefix}"
  environment        = "dev"
  cluster_id         = "${module.cluster.id}"
  cluster_sg         = "${module.cluster.security_group_id}"
  cluster_role       = "${module.cluster.role_id}"
  load_balancer_name = "${module.alb.name}"
  load_balancer_sg   = "${module.alb.security_group_id}"
  vpc_id             = "${var.vpc_id}"
  target_group       = "true"
  image_repository   = "crccheck/hello-world"
  image_version      = "latest"
  container_cpu      = "256"
  container_memory   = "512"

  container_ports = {
    "8000" = "8000"
  }
}

// Listeners are added manually
resource "aws_alb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.service.target_group_arn}"
    type             = "forward"
  }
}

// ... and SG ingress
resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}
```
