# Azure infrastructure

Azure equivalent of `../aws` and `../gcp`: exactly two Ubuntu 24.04 LTS
AMD64 VMs, each with 4 vCPUs / 16 GiB RAM (`Standard_D4s_v5`) and an
encrypted 100 GiB Premium SSD managed OS disk by default.

| AWS architecture | Azure equivalent |
| --- | --- |
| VPC, 10.20.0.0/16 | Virtual network, 10.20.0.0/16, inside a dedicated resource group |
| Two public subnets across availability zones | Two regional subnets, 10.20.0.0/24 and 10.20.1.0/24, with VMs in zones 1 and 2 |
| Internet gateway and public routes | Explicit Internet route and public IP on each NIC |
| m7i.xlarge instances | Standard_D4s_v5 VMs |
| EC2 key pair | Administrator SSH public key |
| Node security group | Network security group plus node application security group |
| Encrypted gp3 root disks | Encrypted Premium_LRS managed OS disks |

Azure subnets span a region; VMs and their Standard public IPs are zonal.
Public IPs are static and remain allocated until destroyed. Each NIC has a
public IP for explicit outbound connectivity; default subnet outbound access
is disabled. No NAT gateway or load balancer is created.

SSH is allowed only from `admin_cidr`. All private traffic between members of
the node application security group is permitted, along with outbound IPv4
traffic. An explicit deny rule overrides Azure's default broad VNet ingress
allowance. Application ports and the K3s API remain closed publicly.
The VMs have password authentication disabled, Secure Boot and vTPM enabled,
and no managed identity assigned.

## Deploy

Install Terraform >= 1.6 and the Azure CLI. Authenticate to an existing
subscription and ensure the Compute, Network and Resources resource providers
are registered:

```sh
az login
az account set --subscription YOUR_SUBSCRIPTION_ID
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.Resources --wait
```

Your identity needs permission to manage the resource group and declared
compute/network resources (for example, Contributor at subscription scope).
The AzureRM provider can also register resource providers during planning;
that requires subscription-level permissions. For CI, use the provider's
standard service principal or workload identity authentication environment
variables; never commit credentials.

Copy root `.env.example` to `.env` if it does not exist. Set
`TF_VAR_azure_subscription_id`, `TF_VAR_azure_location`, `TF_VAR_admin_cidr`,
and `TF_VAR_ssh_public_key_path`. The shared `project_name`, `ssh_username`
and `root_volume_size` inputs apply here too. Supply an Azure-supported
OpenSSH public key (RSA of at least 2048 bits or Ed25519).
AWS- and GCP-specific variables are unused by this configuration.

Choose a region with available `Standard_D4s_v5` capacity and quota in both
zones. Override `TF_VAR_azure_zones` with a literal JSON list if needed:

```dotenv
TF_VAR_azure_zones=["1","2"]
```

From the repository root in PowerShell:

```powershell
./scripts/terraform.ps1 azure init
./scripts/terraform.ps1 azure fmt -check
./scripts/terraform.ps1 azure validate
./scripts/terraform.ps1 azure plan -out=azure.tfplan
./scripts/terraform.ps1 azure apply azure.tfplan
./scripts/terraform.ps1 azure output instances
```

In Bash use `bash scripts/terraform.sh azure` with the same arguments.
Omitting the cloud selector still targets AWS. Every cloud directory has
separate state and a provider lock file. Terraform itself does not read
`.env`; the wrappers parse literal assignments without executing them.
For CI, export inputs and run `terraform -chdir=terraform/azure` directly.

Connect with `ssh -i <private-key-path> ubuntu@<public-ip>` or the configured
`ssh_username`. Use private IPs for node-to-node communication.

This creates infrastructure only; it does not install K3s or platform services.
Two nodes do not provide a highly available K3s embedded-etcd control plane.
The image uses `latest` at deployment; existing VMs are not automatically
updated when a new image is published. Review plans before applying.
Managed OS disks are deleted with their VMs by the provider's default behavior.
Back up important data, and configure a shared remote backend before
collaborating on deployments. VMs, managed disks, public IPs and applicable
data transfer incur charges. Azure bills managed disks by disk tier, so a
100 GiB disk can be billed at a larger tier.

To remove this infrastructure:

```powershell
./scripts/terraform.ps1 azure destroy
```

References: [AzureRM VM resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine),
[Dsv5 VM sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/dsv5-series),
and [Canonical Ubuntu image identifiers](https://ubuntu.com/azure/docs/azure-how-to/find-ubuntu-images/).
