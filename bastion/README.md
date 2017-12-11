## Bastion

Template for provisioning an auto-scaling bastion instance with static IP.
Authorized keys are added at launch, and ingress is limited to the specified
CIDR blocks.

- Login: `ssh forward@<bastion-ip>`
- Tunnel: `ssh -t forward@<bastion-ip> "tunnel user@<destination-ip>"`

NOTE: `tunnel` is just `ssh -i <path-to-pem>` in a bash script.
