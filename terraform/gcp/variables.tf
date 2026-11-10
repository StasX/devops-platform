variable "gcp_project_id" {
  description = "Existing Google Cloud project with billing and the Compute Engine API enabled."
  type        = string
}

variable "gcp_region" {
  description = "Region in which to create both subnets and nodes."
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Prefix used for resource names and labels."
  type        = string
  default     = "devops-platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,38}[a-z0-9]$", var.project_name))
    error_message = "Use 2-40 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "admin_cidr" {
  description = "Trusted IPv4 CIDR allowed to connect over SSH, typically your public IP with /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Supply a valid trusted IPv4 CIDR; unrestricted 0.0.0.0/0 is not allowed."
  }
}

variable "ssh_username" {
  description = "Linux username associated with the supplied SSH public key."
  type        = string
  default     = "ubuntu"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh_username))
    error_message = "Supply a valid Linux username of up to 32 characters."
  }
}

variable "ssh_public_key_path" {
  description = "Local path to an existing OpenSSH public key, never the private key."
  type        = string
}

variable "root_volume_size" {
  description = "Size in GiB of each encrypted balanced persistent boot disk."
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 20 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Root volume size must be a whole number of at least 20 GiB."
  }
}
