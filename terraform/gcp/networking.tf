data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

resource "google_compute_network" "main" {
  name                            = var.project_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

# GCP subnets are regional; place each node in a separate subnet and zone.
resource "google_compute_subnetwork" "public" {
  for_each = local.nodes

  name          = "${var.project_name}-public-${each.value + 1}"
  network       = google_compute_network.main.id
  region        = var.gcp_region
  ip_cidr_range = cidrsubnet("10.20.0.0/16", 8, each.value)
}

resource "google_compute_route" "internet" {
  name             = "${var.project_name}-internet"
  network          = google_compute_network.main.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}
