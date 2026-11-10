data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  nodes = {
    node-1 = 0
    node-2 = 1
  }
}

resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                         = nonsensitive(data.aws_ssm_parameter.ubuntu_ami.value)
  instance_type               = "m7i.xlarge"
  subnet_id                   = aws_subnet.public[each.key].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nodes.id]
  key_name                    = var.ssh_key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.project_name}-${each.key}" }

  depends_on = [aws_route_table_association.public]
}
