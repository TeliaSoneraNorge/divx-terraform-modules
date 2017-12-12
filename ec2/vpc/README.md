## ec2/vpc

This is a module which simplifies setting up a new VPC and getting it into a useful state:

- Creates one public subnet per availability zone (with a shared route table and internet gateway).
- Creates the desired number of private subnets (with one NAT gateway and route table per subnet).
- Evenly splits the specified CIDR block between public/private subnets.

Note that each private subnet has a route table which targets an individual NAT gateway when accessing
the internet, which means that instances in a given private subnet will have a static IP.
