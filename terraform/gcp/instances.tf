data "google_compute_image" "ubuntu" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts-amd64"
}

locals {
  nodes = {
    node-1 = 0
    node-2 = 1
  }
  node_tag = "${var.project_name}-nodes"
}

resource "google_compute_instance" "nodes" {
  for_each = local.nodes

  name         = "${var.project_name}-${each.key}"
  machine_type = "n2-standard-4"
  zone         = data.google_compute_zones.available.names[each.value]
  tags         = [local.node_tag]

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.root_volume_size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public[each.key].id
    access_config {}
  }

  metadata = {
    ssh-keys               = "${var.ssh_username}:${trimspace(file(pathexpand(var.ssh_public_key_path)))}"
    block-project-ssh-keys = "TRUE"
    enable-oslogin         = "FALSE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [
    google_compute_route.internet,
    google_compute_firewall.ssh,
    google_compute_firewall.nodes,
    google_compute_firewall.internet,
  ]
}
