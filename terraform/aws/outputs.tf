output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "instances" {
  description = "Instance IDs and addresses. Use private IPs for communication between nodes."
  value = {
    for name, instance in aws_instance.nodes : name => {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    }
  }
}
