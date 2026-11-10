# Offline plan test. Requires Terraform >= 1.7 for mock providers.
mock_provider "vsphere" {
  mock_data "vsphere_virtual_machine" {
    defaults = {
      id                      = "11111111-1111-4111-8111-111111111111"
      guest_id                = "ubuntu64Guest"
      firmware                = "efi"
      scsi_type               = "pvscsi"
      network_interface_types = ["vmxnet3"]
      disks = [{
        size             = 20
        thin_provisioned = true
        eagerly_scrub    = false
      }]
    }
  }
}

variables {
  vsphere_user           = "test-only"
  vsphere_password       = "test-only"
  vsphere_server         = "vcenter.example.com"
  vsphere_datacenter     = "dc"
  vsphere_cluster        = "cluster"
  vsphere_template       = "templates/ubuntu"
  vsphere_storage_policy = "encrypted"
  vsphere_dns_servers    = ["10.20.0.1"]
  admin_cidr             = "203.0.113.10/32"
  ssh_public_key_path    = "tests/fixtures/ssh.pub"
  vsphere_nodes = {
    node-1 = {
      network      = "vlan-1"
      datastore    = "datastore-1"
      ipv4_address = "10.20.0.10"
      ipv4_prefix  = 24
      ipv4_gateway = "10.20.0.1"
    }
    node-2 = {
      network      = "vlan-2"
      datastore    = "datastore-2"
      ipv4_address = "10.20.1.10"
      ipv4_prefix  = 24
      ipv4_gateway = "10.20.1.1"
    }
  }
}

run "two_nodes_and_bootstrap" {
  command = plan

  assert {
    condition = length(vsphere_virtual_machine.nodes) == 2 && alltrue([
      for node in vsphere_virtual_machine.nodes : node.num_cpus == 4 && node.memory == 16384 && node.disk[0].size == 100
    ])
    error_message = "Both nodes must have 4 CPUs, 16 GiB RAM and 100 GiB root disks."
  }

  assert {
    condition     = vsphere_compute_cluster_vm_anti_affinity_rule.nodes.mandatory && vsphere_compute_cluster_vm_anti_affinity_rule.nodes.enabled
    error_message = "Host separation must be enabled and mandatory."
  }

  assert {
    condition = alltrue([for name, node in vsphere_virtual_machine.nodes :
      yamldecode(base64decode(node.extra_config["guestinfo.metadata"])).network.ethernets.primary.addresses[0] == "${var.vsphere_nodes[name].ipv4_address}/${var.vsphere_nodes[name].ipv4_prefix}" &&
      yamldecode(base64decode(node.extra_config["guestinfo.metadata"])).network.ethernets.primary.routes[0].via == var.vsphere_nodes[name].ipv4_gateway &&
      yamldecode(base64decode(node.extra_config["guestinfo.metadata"])).network.ethernets.primary.dhcp4 == false
    ])
    error_message = "GuestInfo must contain the configured static network metadata."
  }

  assert {
    condition = alltrue([for name, node in vsphere_virtual_machine.nodes :
      strcontains(base64decode(node.extra_config["guestinfo.userdata"]), "#cloud-config") &&
      yamldecode(base64decode(node.extra_config["guestinfo.userdata"])).ssh_pwauth == false &&
      contains([for command in yamldecode(base64decode(node.extra_config["guestinfo.userdata"])).runcmd : join(" ", command)], "ufw allow from 203.0.113.10/32 to any port 22 proto tcp") &&
      contains([for command in yamldecode(base64decode(node.extra_config["guestinfo.userdata"])).runcmd : join(" ", command)], "ufw allow from ${var.vsphere_nodes[name == "node-1" ? "node-2" : "node-1"].ipv4_address} to any")
    ])
    error_message = "Bootstrap must disable password SSH and allow only administrator SSH and peer traffic."
  }
}
