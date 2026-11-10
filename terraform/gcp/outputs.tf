output "vpc_id" {
  description = "ID of the created VPC."
  value       = google_compute_network.main.id
}

output "instances" {
  description = "Instance IDs and addresses. Use private IPs for communication between nodes."
  value = {
    for name, instance in google_compute_instance.nodes : name => {
      id         = instance.id
      zone       = instance.zone
      public_ip  = instance.network_interface[0].access_config[0].nat_ip
      private_ip = instance.network_interface[0].network_ip
    }
  }
}
