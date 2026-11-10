resource "azurerm_virtual_network" "main" {
  name                = var.project_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

# Azure subnets are regional; the VMs and public IPs are zonal.
resource "azurerm_subnet" "public" {
  for_each = local.nodes

  name                            = "${var.project_name}-public-${each.value + 1}"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [cidrsubnet("10.20.0.0/16", 8, each.value)]
  default_outbound_access_enabled = false
}

resource "azurerm_route_table" "public" {
  name                = "${var.project_name}-public"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  route {
    name           = "internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "public" {
  for_each = local.nodes

  subnet_id      = azurerm_subnet.public[each.key].id
  route_table_id = azurerm_route_table.public.id
}

resource "azurerm_public_ip" "nodes" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.azure_zones[each.value]]
  tags                = local.tags
}

resource "azurerm_network_interface" "nodes" {
  for_each = local.nodes

  name                = "${var.project_name}-${each.key}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.public[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nodes[each.key].id
  }
}
