# AWS infrastructure

Creates a VPC (`10.20.0.0/16`), two public subnets in different availability
zones, an internet gateway, routing, and exactly two `m7i.xlarge` EC2 instances
(4 vCPU / 16 GiB each). Instances use the current Canonical Ubuntu 24.04 LTS
AMD64 AMI and encrypted 100 GiB gp3 root volumes by default.

## Deploy

Install Terraform >= 1.6 and configure AWS credentials using your usual AWS
profile or environment variables. Do not put credentials in Terraform files.
Your identity needs permission to manage the declared EC2/VPC resources and
read the public Ubuntu AMI parameter from SSM Parameter Store.

Copy `.env.example` to `.env` in the repository root and edit the values.
Terraform receives inputs through `TF_VAR_*` environment variables. The root
`.env` is ignored by Git. Terraform does not read `.env` itself: use the wrappers
below, which load it before every command and forward arguments to Terraform.
Values are literal `KEY=VALUE`, optionally enclosed in matching single or double
quotes. Use full-line comments; shell expressions and interpolation are not
evaluated. AWS profile/credential environment variables can also be set there.

From the repository root, using PowerShell:

```powershell
Copy-Item .env.example .env
# Edit .env before planning.
./scripts/terraform.ps1 init
./scripts/terraform.ps1 fmt -check
./scripts/terraform.ps1 validate
./scripts/terraform.ps1 plan -out=aws.tfplan
./scripts/terraform.ps1 apply aws.tfplan
./scripts/terraform.ps1 output instances
```

Or using Bash, from the repository root:

```bash
cp .env.example .env
# Edit .env before planning.
bash scripts/terraform.sh init
bash scripts/terraform.sh plan -out=aws.tfplan
bash scripts/terraform.sh apply aws.tfplan
bash scripts/terraform.sh output instances
```

Connect with `ssh -i <private-key-path> ubuntu@<public-ip>`.
Public IPs can change after an instance is stopped and started.

SSH is restricted to `admin_cidr`. All traffic between instances in the node
security group is permitted for future K3s networking. Outbound IPv4 traffic
is permitted. Application ports and the K3s API are not exposed publicly;
use SSH tunnels or add deliberate ingress rules when deploying services.
There is no NAT gateway or load balancer.

This provisions infrastructure only; it does not install K3s, Jenkins, Nexus,
Artifactory, or Gitea. Two instances do not provide a highly available K3s
embedded-etcd control plane; that requires at least three server nodes.

The AMI is resolved during planning; a later plan may select a newer image
and propose instance replacement. Review plans carefully. Root disks are
deleted on termination: configure backups before storing important data.
Local state must be protected; configure a shared remote backend before
collaborating on deployments.

Both EC2 instances, EBS storage, public IPv4 addresses, and applicable data
transfer incur charges. At the previously discussed us-east-1 Linux On-Demand
rate of $0.2016/hour per instance, compute alone is about $294.34/month for
two instances at 730 hours; confirm current regional rates before applying.

To remove resources when they are no longer needed:

```powershell
./scripts/terraform.ps1 destroy
```
