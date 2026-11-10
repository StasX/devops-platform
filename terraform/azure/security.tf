resource "azurerm_application_security_group" "nodes" {
  name                = "${var.project_name}-nodes"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags
}

resource "azurerm_network_interface_application_security_group_association" "nodes" {
  for_each = local.nodes

  network_interface_id          = azurerm_network_interface.nodes[each.key].id
  application_security_group_id = azurerm_application_security_group.nodes.id
}

resource "azurerm_network_security_group" "nodes" {
  name                = "${var.project_name}-nodes"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  security_rule {
    name                                       = "admin-ssh"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "22"
    source_address_prefix                      = var.admin_cidr
    destination_application_security_group_ids = [azurerm_application_security_group.nodes.id]
  }

  security_rule {
    name                                       = "private-node-traffic"
    priority                                   = 110
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "*"
    source_application_security_group_ids      = [azurerm_application_security_group.nodes.id]
    destination_application_security_group_ids = [azurerm_application_security_group.nodes.id]
  }

  # Override Azure's default AllowVNetInBound rule to restrict access to nodes.
  security_rule {
    name                       = "deny-other-ingress"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "outbound-access"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "0.0.0.0/0"
  }
}

resource "azurerm_network_interface_security_group_association" "nodes" {
  for_each = local.nodes

  network_interface_id      = azurerm_network_interface.nodes[each.key].id
  network_security_group_id = azurerm_network_security_group.nodes.id
}
