locals {
  nodes = {
    node-1 = 0
    node-2 = 1
  }
}

resource "azurerm_linux_virtual_machine" "nodes" {
  for_each = local.nodes

  name                            = "${var.project_name}-${each.key}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  zone                            = var.azure_zones[each.value]
  size                            = "Standard_D4s_v5"
  admin_username                  = var.ssh_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nodes[each.key].id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = local.tags

  admin_ssh_key {
    username   = var.ssh_username
    public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  }

  os_disk {
    name                 = "${var.project_name}-${each.key}-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.root_volume_size
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  depends_on = [
    azurerm_subnet_route_table_association.public,
    azurerm_network_interface_security_group_association.nodes,
    azurerm_network_interface_application_security_group_association.nodes,
  ]
}
