variable "azure_subscription_id" {
  description = "Existing Azure subscription in which to create the infrastructure."
  type        = string
}

variable "azure_location" {
  description = "Azure region supporting the selected VM size in both availability zones."
  type        = string
  default     = "eastus"
}

variable "azure_zones" {
  description = "Two distinct availability zones in the selected region, one per node."
  type        = list(string)
  default     = ["1", "2"]

  validation {
    condition = (
      length(var.azure_zones) == 2 &&
      length(distinct(var.azure_zones)) == 2 &&
      alltrue([for zone in var.azure_zones : contains(["1", "2", "3"], zone)])
    )
    error_message = "Supply exactly two distinct zones chosen from 1, 2 and 3."
  }
}

variable "project_name" {
  description = "Prefix used for resource names and tags."
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
  description = "Linux administrator username associated with the supplied SSH public key."
  type        = string
  default     = "ubuntu"

  validation {
    condition = (
      can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh_username)) &&
      !contains(["root", "admin", "administrator", "user", "test", "guest"], var.ssh_username)
    )
    error_message = "Supply a valid Linux username of up to 32 characters, avoiding reserved Azure administrator names."
  }
}

variable "ssh_public_key_path" {
  description = "Local path to an existing Azure-supported OpenSSH public key, never the private key."
  type        = string
}

variable "root_volume_size" {
  description = "Size in GiB of each encrypted Premium SSD managed OS disk."
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 30 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Root volume size must be a whole number of at least 30 GiB to fit the Ubuntu OS image."
  }
}
