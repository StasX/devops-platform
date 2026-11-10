resource "vsphere_virtual_machine" "nodes" {
  for_each = var.vsphere_nodes

  name              = "${var.project_name}-${each.key}"
  folder            = vsphere_folder.main.path
  resource_pool_id  = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id      = data.vsphere_datastore.nodes[each.key].id
  storage_policy_id = data.vsphere_storage_policy.encrypted.id
  num_cpus          = 4
  memory            = 16384
  guest_id          = data.vsphere_virtual_machine.template.guest_id
  scsi_type         = data.vsphere_virtual_machine.template.scsi_type
  firmware          = data.vsphere_virtual_machine.template.firmware
  annotation        = "Project: ${var.project_name}; ManagedBy: Terraform"

  network_interface {
    network_id   = data.vsphere_network.nodes[each.key].id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label             = "disk0"
    size              = var.root_volume_size
    thin_provisioned  = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    eagerly_scrub     = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
    storage_policy_id = data.vsphere_storage_policy.encrypted.id
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  # DataSourceVMware configures networking and first-boot security in the guest.
  extra_config = {
    "guestinfo.metadata"          = base64encode(yamlencode(local.metadata[each.key]))
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode("#cloud-config\n${yamlencode(local.user_data[each.key])}")
    "guestinfo.userdata.encoding" = "base64"
  }

  lifecycle {
    precondition {
      condition = (
        length(data.vsphere_virtual_machine.template.disks) == 1 &&
        length(data.vsphere_virtual_machine.template.network_interface_types) == 1
      )
      error_message = "The Ubuntu template must have exactly one SCSI disk and one Ethernet NIC."
    }
    precondition {
      condition     = var.root_volume_size >= data.vsphere_virtual_machine.template.disks[0].size
      error_message = "root_volume_size cannot be smaller than the template disk."
    }
  }
}

resource "vsphere_compute_cluster_vm_anti_affinity_rule" "nodes" {
  name                = "${var.project_name}-separate-hosts"
  compute_cluster_id  = data.vsphere_compute_cluster.main.id
  virtual_machine_ids = [for node in vsphere_virtual_machine.nodes : node.id]
  enabled             = true
  mandatory           = true

  lifecycle {
    replace_triggered_by = [vsphere_virtual_machine.nodes]
  }
}
