variable "aws_region" {
  description = "AWS region supplied by TF_VAR_aws_region, loaded from the root .env by the wrapper scripts."
  type        = string

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "Set TF_VAR_aws_region to a non-empty AWS region in the root .env."
  }
}

variable "project_name" {
  description = "Prefix used for resource names and tags."
  type        = string
  default     = "devops-platform"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair in the selected AWS region."
  type        = string
}

variable "admin_cidr" {
  description = "Trusted IPv4 CIDR allowed to connect over SSH, typically your public IP with /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Supply a valid trusted IPv4 CIDR; unrestricted 0.0.0.0/0 is not allowed."
  }
}

variable "root_volume_size" {
  description = "Size in GiB of each instance's encrypted gp3 root disk."
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 20 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Root volume size must be a whole number of at least 20 GiB."
  }
}
