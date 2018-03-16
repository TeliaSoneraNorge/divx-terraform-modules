## Container

Set up an ECS cluster and register services with ease. The modules set up the following:

#### container/cluster

- Autoscaling group/launch configuration.
- CoreOS instances with ECS agent running.
- A security group for the cluster (with all egress and ingress from the specified load balancers).
- CloudWatch log group.
- IAM role/instance profile with appropriate privileges.

#### container/service

- Can be used with or without a load balancer.
- Usable with either an ALB or a NLB.
- Sets up and enables logging for the service.
- Creates IAM roles for the ECS service.

Note that task definitions have to be created manually (cannot be abstracted) because of `volume` blocks.

#### container/target

NOTE: Should probably be moved to `ec2` as it is not specific to ECS.

- Creates a target group and a variable number of listeners (based on a list of maps).
- Removes a lot of boilerplate.
- Usable with either an ALB or a NLB.
