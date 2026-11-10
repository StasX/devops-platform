variable "vsphere_user" {
  description = "vCenter identity, supplied through TF_VAR_vsphere_user."
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vCenter password, supplied through TF_VAR_vsphere_password."
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vCenter FQDN or IP address with a trusted TLS certificate."
  type        = string
}

variable "vsphere_datacenter" {
  description = "Existing vCenter datacenter name."
  type        = string
}

variable "vsphere_cluster" {
  description = "Existing DRS-enabled cluster with at least two eligible ESXi hosts."
  type        = string
}

variable "vsphere_template" {
  description = "Inventory path of a prepared Ubuntu 24.04 AMD64 template with VMware cloud-init support."
  type        = string
}

variable "vsphere_storage_policy" {
  description = "Existing VM storage policy configured for encryption and compatible with both datastores."
  type        = string
}

variable "vsphere_nodes" {
  description = "Exactly two nodes on distinct existing routed port groups/subnets. Reserve these static IPs outside DHCP."
  type = map(object({
    network      = string
    datastore    = string
    ipv4_address = string
    ipv4_prefix  = number
    ipv4_gateway = string
  }))

  validation {
    condition     = toset(keys(var.vsphere_nodes)) == toset(["node-1", "node-2"])
    error_message = "Define exactly node-1 and node-2."
  }

  validation {
    condition = alltrue([for node in values(var.vsphere_nodes) :
      can(cidrnetmask("${node.ipv4_address}/${node.ipv4_prefix}")) &&
      can(cidrnetmask("${node.ipv4_gateway}/32")) &&
      node.ipv4_prefix >= 1 && node.ipv4_prefix <= 30 && floor(node.ipv4_prefix) == node.ipv4_prefix &&
      try(cidrhost("${node.ipv4_address}/${node.ipv4_prefix}", 0) == cidrhost("${node.ipv4_gateway}/${node.ipv4_prefix}", 0), false) &&
      node.ipv4_address != node.ipv4_gateway
    ])
    error_message = "Use valid static IPv4 addresses, integer prefixes 1-30 and a different gateway within each node's subnet."
  }

  validation {
    condition = (
      length(distinct([for node in values(var.vsphere_nodes) : node.network])) == 2 &&
      length(distinct([for node in values(var.vsphere_nodes) : node.ipv4_address])) == 2 &&
      length(distinct([for node in values(var.vsphere_nodes) : try(cidrhost("${node.ipv4_address}/${node.ipv4_prefix}", 0), "invalid")])) == 2
    )
    error_message = "Use distinct port groups, IP addresses and subnet network addresses for the two nodes."
  }
}

variable "vsphere_dns_servers" {
  description = "IPv4 DNS servers reachable through the existing network."
  type        = list(string)

  validation {
    condition     = length(var.vsphere_dns_servers) > 0 && alltrue([for ip in var.vsphere_dns_servers : can(cidrnetmask("${ip}/32"))])
    error_message = "Supply at least one valid IPv4 DNS server."
  }
}

variable "project_name" {
  description = "Prefix used for VM names and the dedicated inventory folder."
  type        = string
  default     = "devops-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.project_name))
    error_message = "Use 2-40 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "admin_cidr" {
  description = "Trusted IPv4 CIDR allowed SSH access, as seen by the guest after any upstream NAT."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Supply a valid trusted IPv4 CIDR; unrestricted 0.0.0.0/0 is not allowed."
  }
}

variable "ssh_username" {
  description = "Linux administrator username to configure through cloud-init."
  type        = string
  default     = "ubuntu"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh_username)) && var.ssh_username != "root"
    error_message = "Supply a non-root Linux username of up to 32 characters."
  }
}

variable "ssh_public_key_path" {
  description = "Local path to an existing OpenSSH public key, never the private key."
  type        = string
}

variable "root_volume_size" {
  description = "Size in GiB of each encrypted VMDK; must be at least the template disk size."
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 20 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Root volume size must be a whole number of at least 20 GiB."
  }
}
