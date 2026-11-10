# Routing, VLANs and Internet/NAT connectivity belong to the existing network.
# A vSphere port group alone does not provide a router or security group.
data "vsphere_network" "nodes" {
  for_each = var.vsphere_nodes

  name          = each.value.network
  datacenter_id = data.vsphere_datacenter.main.id
}

locals {
  metadata = {
    for name, node in var.vsphere_nodes : name => {
      instance-id    = "${var.project_name}-${name}"
      local-hostname = "${var.project_name}-${name}"
      network = {
        version = 2
        ethernets = {
          primary = {
            match     = { name = "e*" }
            dhcp4     = false
            dhcp6     = false
            addresses = ["${node.ipv4_address}/${node.ipv4_prefix}"]
            routes = [{
              to  = "0.0.0.0/0"
              via = node.ipv4_gateway
            }]
            nameservers = { addresses = var.vsphere_dns_servers }
          }
        }
      }
    }
  }
}
