## Bastion

Template for provisioning an auto-scaling bastion instance with static IP.
Authorized keys are added at launch, and ingress is limited to the specified
CIDR blocks.

- Login: `ssh forward@<bastion-ip>`
- Tunnel: `ssh -t forward@<bastion-ip> "tunnel user@<destination-ip>"`

NOTE: `tunnel` is just `ssh -i <path-to-pem>` in a bash script.


#### Create the necessary certificates

```bash
ssh-keygen -t rsa -b 4096 -f bless-ca -C "SSH CA Key"
chmod 0644 bless-ca
```

Sign your user public key:

```bash
ssh-keygen -s bless-ca -I user_forward -n forward -V +52w ~/.ssh/id_rsa.pub
```
