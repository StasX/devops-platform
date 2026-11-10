# DevOps Platform

Terraform infrastructure for a two-node DevOps platform on AWS, Google Cloud,
Azure or VMware vSphere. Each target provisions two Ubuntu 24.04 LTS AMD64
VMs with 4 vCPUs, 16 GiB RAM and a 100 GiB root disk per node by default.

The repository currently implements the infrastructure layer. Directories for
K3s, Helm charts, Jenkins, monitoring, services and additional documentation
are placeholders; deploying Terraform does not install those components.

## Infrastructure

Choose one target for a deployment. The directories are independent Terraform
roots with separate state and provider lock files.

| Target | Compute | Networking and node separation | Setup guide |
| --- | --- | --- | --- |
| AWS | Two `m7i.xlarge` EC2 instances | VPC, two public subnets in different availability zones, public IPv4 and security group | [AWS](terraform/aws/README.md) |
| Google Cloud | Two `n2-standard-4` VMs | Custom VPC, two regional subnets, VMs in different zones, public IPv4 and firewall rules | [GCP](terraform/gcp/README.md) |
| Azure | Two `Standard_D4s_v5` VMs | VNet, two regional subnets, VMs in different zones, static public IPv4 and security groups | [Azure](terraform/azure/README.md) |
| vSphere | Two template clones | Existing routed port groups, static private IPs and mandatory DRS host separation | [vSphere](terraform/vsphere/README.md) |

Cloud networks use `10.20.0.0/16` with node subnets `10.20.0.0/24` and
`10.20.1.0/24`. vSphere consumes existing networks; its example configuration
uses the same subnet ranges. Separate ESXi hosts provide host separation,
while physical site and storage fault domains depend on your environment.

SSH is restricted to the configured administrator CIDR. Private node traffic
and outbound IPv4 traffic are allowed. Application ports and the K3s API are
not exposed publicly. No NAT gateway or load balancer is provisioned;
vSphere Internet access and public IP/NAT mappings are supplied externally.

Root disks use cloud-managed encryption or, on vSphere, an existing
encryption-enabled storage policy. Two nodes are insufficient for a highly
available K3s embedded-etcd control plane.

## Repository layout

```text
terraform/
  aws/         AWS infrastructure
  gcp/         Google Cloud infrastructure
  azure/       Azure infrastructure
  vsphere/     vSphere infrastructure and offline plan test
scripts/       Terraform wrappers for PowerShell and Bash
docs/          Reserved for additional documentation
helm/charts/   Reserved for Helm charts
jenkins/       Reserved for Jenkins configuration
k3s/           Reserved for K3s configuration
monitoring/    Reserved for monitoring configuration
services/      Reserved for platform services
.env.example   Input examples for all infrastructure targets
```

## Getting started

Install Terraform >= 1.6 and use PowerShell or Bash. Configure credentials
and prerequisites for your selected target using its setup guide above.
AWS needs an existing regional EC2 key pair. GCP and Azure need an existing
project/subscription and a local SSH public key. vSphere needs vCenter, a
DRS-enabled cluster, a prepared Ubuntu cloud-init template, routed port groups,
datastores and an encryption-enabled storage policy.

From the repository root, copy the example configuration once:

```powershell
Copy-Item .env.example .env
```

Or in Bash:

```bash
cp .env.example .env
```

Edit `.env` before planning. Replace placeholders for your selected target,
set `TF_VAR_admin_cidr` to your trusted IPv4 CIDR, and configure the shared
project name, disk size and applicable SSH inputs. The example administrator
address is a documentation placeholder. For vSphere, use the administrator
source address as seen by the guest after any upstream NAT.

The wrappers load literal `KEY=VALUE` assignments from the root `.env` before
each command. Matching single or double quotes are optional; use full-line
comments. Shell commands, variable expansion and interpolation are not
evaluated. Unrelated target inputs can remain in the file. `.env`, provider
downloads, Terraform state and saved plan files are ignored by Git.

### PowerShell

Choose `aws`, `gcp`, `azure` or `vsphere`:

```powershell
$target = 'aws'
./scripts/terraform.ps1 $target init
./scripts/terraform.ps1 $target fmt -check
./scripts/terraform.ps1 $target validate
./scripts/terraform.ps1 $target plan "-out=$target.tfplan"
# Review the plan before applying.
./scripts/terraform.ps1 $target apply "$target.tfplan"
./scripts/terraform.ps1 $target output instances
```

### Bash

```bash
target=aws
bash scripts/terraform.sh "$target" init
bash scripts/terraform.sh "$target" fmt -check
bash scripts/terraform.sh "$target" validate
bash scripts/terraform.sh "$target" plan -out="$target.tfplan"
# Review the plan before applying.
bash scripts/terraform.sh "$target" apply "$target.tfplan"
bash scripts/terraform.sh "$target" output instances
```

Omitting the target selects AWS for compatibility. Use the same target for
planning, applying, outputs and destruction. Plan paths are relative to the
selected Terraform directory.

In CI, export the required inputs and authentication environment variables,
then run Terraform directly, for example `terraform -chdir=terraform/aws plan`.
Terraform itself does not read `.env`.

## Access and operation

Use `output instances` to obtain node addresses. Connect with the private key
matching your configured key pair or public key:

```sh
ssh -i <private-key-path> ubuntu@<node-address>
```

For GCP, Azure and vSphere, replace `ubuntu` if you changed `ssh_username`.
Use cloud public IPs or routed private addresses as appropriate. vSphere
outputs private addresses; public IPs are managed externally. Use private
addresses for node-to-node communication.

Protect Terraform state and configure a shared remote backend before team
deployments. Review plans for VM replacement and back up persistent data:
managed root disks are deleted when their VMs are destroyed. Cloud resources
incur charges; review regional compute, disk, public IP and transfer pricing
before applying.

To remove a deployment, select its target:

```powershell
./scripts/terraform.ps1 aws destroy
```

Or run `bash scripts/terraform.sh aws destroy`. Replace `aws` with the target
you deployed. vSphere retains existing networks, templates, datastores,
storage policies and the compute cluster.

## Development checks

After initializing a target, run its `fmt -check` and `validate` commands.
The vSphere configuration also includes an offline mocked plan test, requiring
Terraform >= 1.7:

```sh
terraform -chdir=terraform/vsphere test
```

The test checks VM sizing, mandatory host separation and generated networking,
SSH and firewall configuration without connecting to vCenter. Deployment
verification still requires the target environment; for vSphere, confirm
cloud-init completion, UFW rules, storage policy compliance and DRS placement.

[.editorconfig](.editorconfig) and [.gitattributes](.gitattributes) enforce LF
for text files and CRLF for PowerShell (`*.ps1`) files.

## License

Licensed under the [MIT License](LICENSE).
