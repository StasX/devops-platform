# Google Cloud infrastructure

GCP equivalent of `../aws`: exactly two Ubuntu 24.04 LTS AMD64 VMs,
each with 4 vCPUs / 16 GiB RAM (`n2-standard-4`) and a 100 GiB
`pd-balanced` boot disk by default. Persistent disks use Google-managed
encryption and are deleted with their VM.

| AWS architecture | GCP equivalent |
| --- | --- |
| VPC with 10.20.0.0/16 address space | Custom-mode VPC with explicitly allocated subnet ranges |
| Two public subnets in different availability zones | Two regional subnets, 10.20.0.0/24 and 10.20.1.0/24, with VMs in two different zones |
| Internet gateway and public routes | Default internet gateway and explicit 0.0.0.0/0 route |
| m7i.xlarge instances | n2-standard-4 instances |
| EC2 key pair | Instance metadata SSH public key |
| Security group | Tagged VPC firewall rules |
| Encrypted gp3 root disks | Encrypted balanced persistent boot disks |

GCP VPCs are global and subnets are regional rather than zonal. The two
zones are selected from the available zones in `gcp_region`. Choose a
region with at least two available zones supporting N2 machines.
Each VM gets an ephemeral public IPv4 address; use private IPs between nodes.
SSH is allowed only from `admin_cidr`. All private traffic between tagged
nodes and outbound IPv4 traffic are allowed. Application ports and the K3s
API remain closed publicly. No Cloud NAT or load balancer is created.

## Deploy

Install Terraform >= 1.6 and the Google Cloud CLI. Use an existing billed
project, enable `compute.googleapis.com`, and authenticate Terraform:

```sh
gcloud auth application-default login
gcloud services enable compute.googleapis.com --project=YOUR_PROJECT_ID
```

The deploying identity needs permissions to manage Compute Engine networks,
subnets, routes, firewalls and instances, and read images and zones. No VM
service account or cloud API permissions are attached by this configuration.
Instance metadata SSH keys are used; organization policies must permit public
IPs and metadata SSH authentication (OS Login is explicitly disabled).

Copy root `.env.example` to `.env` if it does not already exist. Set
`TF_VAR_gcp_project_id`, `TF_VAR_gcp_region`, `TF_VAR_admin_cidr`, and
`TF_VAR_ssh_public_key_path` to your values. The key path must point to an
existing public key on the machine running Terraform. Shared inputs
`TF_VAR_project_name` and `TF_VAR_root_volume_size` apply to both clouds.
AWS-specific variables are unused by this configuration.

From the repository root in PowerShell:

```powershell
./scripts/terraform.ps1 gcp init
./scripts/terraform.ps1 gcp fmt -check
./scripts/terraform.ps1 gcp validate
./scripts/terraform.ps1 gcp plan -out=gcp.tfplan
./scripts/terraform.ps1 gcp apply gcp.tfplan
./scripts/terraform.ps1 gcp output instances
```

In Bash use `bash scripts/terraform.sh gcp` with the same arguments.
Omitting the cloud selector continues to target AWS. Each cloud directory
has its own Terraform state and provider lock file. Terraform does not load
`.env` itself; the wrappers parse literal assignments without executing them.
For CI, export the inputs and use `terraform -chdir=terraform/gcp` directly.

Connect with `ssh -i <private-key-path> ubuntu@<public-ip>` (or your configured
`ssh_username`). Public IPs can change after a VM is stopped and started.

This creates infrastructure only; it does not install K3s or platform services.
Two nodes do not provide a highly available K3s embedded-etcd control plane.
The Ubuntu image family is resolved during planning; newer images can cause
VM replacement. Review the plan before applying. Back up important data before
replacing or deleting VMs, and configure a remote backend before sharing state.
VMs, disks, public IPv4 addresses and applicable data transfer incur charges.

To remove this infrastructure:

```powershell
./scripts/terraform.ps1 gcp destroy
```

Provider references: [VM instances](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
and [firewall rules](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall).
