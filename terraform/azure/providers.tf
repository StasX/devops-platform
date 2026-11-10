provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
}

locals {
  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.azure_location
  tags     = local.tags
}
