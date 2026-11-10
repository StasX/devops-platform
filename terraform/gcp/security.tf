resource "google_compute_firewall" "ssh" {
  name          = "${var.project_name}-ssh"
  network       = google_compute_network.main.id
  direction     = "INGRESS"
  source_ranges = [var.admin_cidr]
  target_tags   = [local.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "nodes" {
  name        = "${var.project_name}-nodes"
  network     = google_compute_network.main.id
  direction   = "INGRESS"
  source_tags = [local.node_tag]
  target_tags = [local.node_tag]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "internet" {
  name               = "${var.project_name}-egress"
  network            = google_compute_network.main.id
  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [local.node_tag]

  allow {
    protocol = "all"
  }
}
