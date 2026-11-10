output "networks" {
  description = "Existing port groups used by each node."
  value       = { for name, network in data.vsphere_network.nodes : name => network.id }
}

output "instances" {
  description = "VM IDs and configured static private IPs. Public IP/NAT mappings are managed externally."
  value = {
    for name, instance in vsphere_virtual_machine.nodes : name => {
      id         = instance.id
      private_ip = var.vsphere_nodes[name].ipv4_address
      public_ip  = null
    }
  }
}
