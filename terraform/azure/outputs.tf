output "vnet_id" {
  description = "ID of the created virtual network."
  value       = azurerm_virtual_network.main.id
}

output "resource_group_name" {
  description = "Resource group containing the Azure infrastructure."
  value       = azurerm_resource_group.main.name
}

output "instances" {
  description = "VM IDs and addresses. Use private IPs for communication between nodes."
  value = {
    for name, instance in azurerm_linux_virtual_machine.nodes : name => {
      id         = instance.id
      zone       = instance.zone
      public_ip  = azurerm_public_ip.nodes[name].ip_address
      private_ip = azurerm_network_interface.nodes[name].private_ip_address
    }
  }
}
