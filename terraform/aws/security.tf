resource "aws_security_group" "nodes" {
  name_prefix = "${var.project_name}-nodes-"
  description = "Restricted administrator SSH and private communication between nodes"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-nodes" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.nodes.id
  description       = "SSH from the administrator network"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "nodes" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  description                  = "Private node-to-node traffic for K3s and workloads"
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.nodes.id
  description       = "Outbound access for updates and container images"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
