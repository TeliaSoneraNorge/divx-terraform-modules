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
- Creates target group and listeners when used with a load balancer (for dynamic port mapping).
- Sets up and enables logging for the service.
- Creates IAM roles for the ECS service.

Note that task definitions have to be created manually (cannot be abstracted) because of `volume` blocks.
