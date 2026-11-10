provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = false
}

data "vsphere_datacenter" "main" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "main" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_datastore" "nodes" {
  for_each = var.vsphere_nodes

  name          = each.value.datastore
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_template
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_storage_policy" "encrypted" {
  name = var.vsphere_storage_policy
}

resource "vsphere_folder" "main" {
  path          = var.project_name
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.main.id
}
