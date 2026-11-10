# vSphere infrastructure

Creates exactly two Ubuntu 24.04 LTS AMD64 VMs, each with 4 vCPUs,
16 GiB RAM and a 100 GiB VMDK by default, in a dedicated VM folder.
A mandatory DRS anti-affinity rule separates the VMs across ESXi hosts.
Both VMs use an existing encryption-enabled storage policy.

| Cloud architecture | vSphere equivalent |
| --- | --- |
| Two VMs across availability zones | Two clones with a mandatory separate-host DRS rule |
| Separate subnets in a VPC/VNet | Two existing routed VLAN port groups, one per VM |
| Internet gateway and routes | Existing routers/firewalls and configured guest default gateways |
| Public IP addresses | Existing upstream public IP/NAT mappings, if needed |
| Restricted SSH and node security group | Guest UFW rules allowing administrator SSH and all traffic from the peer's private IP |
| Encrypted root disks | Existing encryption-enabled VM storage policy applied to VMs and disks |

The standard vSphere provider does not supply a VPC, subnet router, public-IP
allocator or distributed firewall. This configuration consumes those network
services rather than creating them. It does not require NSX. Separate hosts
within one cluster are not equivalent to separate availability zones or sites;
configure physical/storage fault domains in your environment as needed.

## Prerequisites

- vCenter with a trusted TLS certificate, a DRS-enabled cluster and at least
  two eligible hosts. All eligible hosts must reach both port groups and the
  selected datastores. The rule is installed after cloning; initial placement
  may briefly share a host until DRS enforces separation.
- An existing VM encryption storage policy, a configured key provider and
  compatible encrypted storage. The policy name is an input; Terraform cannot
  infer from its name whether an administrator configured encryption correctly.
  Verify compliance in vCenter. Datastores may be shared or distinct.
- Two existing port groups on distinct routed subnets. The sample inputs use
  `10.20.0.0/24` and `10.20.1.0/24`. Reserve the VM addresses outside DHCP;
  allow private traffic between them and outbound DNS, updates and image pulls.
  Supply upstream routing/NAT for Internet access. Public ingress and public
  IP/NAT mappings remain under your network administrator's control.
- A prepared Ubuntu 24.04 LTS AMD64 **VM template** with exactly one SCSI
  root disk and one Ethernet NIC. Its disk must not exceed `root_volume_size`.
  Install and enable `open-vm-tools`, `cloud-init`, `openssh-server`, `sudo`
  and `ufw` before converting it to a template. Use a current cloud-init with
  `DataSourceVMware` enabled for GuestInfo metadata/user-data. Do not disable
  cloud-init networking; remove stale static network configuration.
- Clean cloud-init state, SSH host keys and machine identity before sealing
  the template; ensure clones regenerate unique identities and host keys.
  Use a template with no inherited login keys or credentials, no permissive
  UFW rules and an enabled default-deny inbound firewall. This keeps first
  boot protected before cloud-init adds the administrator and peer rules.
  Do not use an unprepared installed Ubuntu VM or an untested OVF deployment.

GuestInfo metadata supplies a static address, default route and DNS using
cloud-init network v2. The Ethernet match `e*` assumes the template's single
NIC uses a standard `ens*`, `enp*` or `eth*` name. User-data installs your
SSH public key, disables password/root SSH, grows the root filesystem and
configures UFW. It allows SSH from `admin_cidr`, any inbound traffic from
the other node's configured private IP, and outbound traffic. Application
ports and the K3s API are otherwise closed. If NAT changes the SSH source,
set `admin_cidr` to the source CIDR the guest actually sees. Upstream controls
must prevent source-IP spoofing; UFW is not a distributed security group.

## Deploy

Install Terraform >= 1.6. The vCenter identity needs inventory read, VM folder
creation, clone/configure/power operations, datastore allocation, network
assignment, encryption policy access and cluster DRS rule permissions.
Trust your vCenter certificate/CA on the Terraform machine; certificate
verification is enabled.

Copy root `.env.example` to `.env` if it does not exist. Configure the
`TF_VAR_vsphere_*` inputs, shared `project_name`, `admin_cidr`,
`root_volume_size`, `ssh_username` and `ssh_public_key_path`. The node map
must contain exactly `node-1` and `node-2`, each with a port group, datastore,
static IPv4 address, prefix and gateway. The example `.env` contains literal
JSON for this map and DNS server list; keep each assignment on one line.

Set `TF_VAR_vsphere_user` and `TF_VAR_vsphere_password` in the process environment
or local ignored `.env`. Both inputs are marked sensitive. Do not commit credentials.
Unrelated cloud inputs in `.env` are unused by this configuration.

From the repository root in PowerShell:

```powershell
./scripts/terraform.ps1 vsphere init
./scripts/terraform.ps1 vsphere fmt -check
./scripts/terraform.ps1 vsphere validate
./scripts/terraform.ps1 vsphere plan -out=vsphere.tfplan
./scripts/terraform.ps1 vsphere apply vsphere.tfplan
./scripts/terraform.ps1 vsphere output instances
```

In Bash use `bash scripts/terraform.sh vsphere` with the same arguments.
Omitting the selector continues to target AWS. Each target directory has its
own state and provider lock file. For CI, export inputs and run
`terraform -chdir=terraform/vsphere` directly; Terraform does not read `.env`.

For an offline mocked plan check, run `terraform -chdir=terraform/vsphere test`
with Terraform >= 1.7. It checks sizing, host separation and rendered network,
SSH and firewall settings without connecting to vCenter. The public key under
`tests/fixtures` is a test fixture only; never use it for a deployment.

After deployment, use the vSphere console to confirm `cloud-init status --wait`
succeeds, `sudo ufw status verbose` has the expected rules, and the storage
policy and DRS rule are compliant. Terraform's guest-network waiter does not
verify cloud-init completion or firewall health. Connect through your routed
administrator network with `ssh -i <private-key-path> ubuntu@<private-ip>`
(or your configured username). `instances.public_ip` is null because public
addresses are managed externally.

This provisions VMs and first-boot access/security only; it does not install
K3s or platform services. Two nodes are insufficient for a highly available
K3s embedded-etcd control plane. Cloud-init applies on first boot: changing
user-data on an existing VM does not reliably reconfigure it. Rebuild nodes
deliberately or use configuration management for subsequent changes.
Review replacement plans and back up data before rebuilding; Terraform deletes
managed VMDKs when destroying the VMs. Protect state and use a shared remote
backend before collaborating.

To remove the managed VMs, folder and DRS rule (existing networks, datastores,
templates, storage policy and cluster are retained):

```powershell
./scripts/terraform.ps1 vsphere destroy
```

References: [vSphere VM resource](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/resources/virtual_machine),
[DRS anti-affinity rules](https://registry.terraform.io/providers/vmware/vsphere/latest/docs/resources/compute_cluster_vm_anti_affinity_rule)
and [cloud-init VMware datasource](https://docs.cloud-init.io/en/latest/reference/datasources/vmware.html).
