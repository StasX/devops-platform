locals {
  user_data = {
    for name, node in var.vsphere_nodes : name => {
      users = [{
        name                = var.ssh_username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = ["ALL=(ALL) NOPASSWD:ALL"]
        lock_passwd         = true
        ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
      }]
      disable_root  = true
      ssh_pwauth    = false
      growpart      = { mode = "auto", devices = ["/"], ignore_growroot_disabled = false }
      resize_rootfs = true
      write_files = [{
        path        = "/etc/ssh/sshd_config.d/00-platform.conf"
        owner       = "root:root"
        permissions = "0644"
        content     = "PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n"
      }]
      runcmd = concat(
        [
          ["ufw", "default", "deny", "incoming"],
          ["ufw", "default", "allow", "outgoing"],
          ["ufw", "allow", "from", var.admin_cidr, "to", "any", "port", "22", "proto", "tcp"],
        ],
        [for peer_name, peer in var.vsphere_nodes :
          ["ufw", "allow", "from", peer.ipv4_address, "to", "any"] if peer_name != name
        ],
        [
          ["ufw", "--force", "enable"],
          ["sshd", "-t"],
          ["systemctl", "restart", "ssh"],
        ]
      )
    }
  }
}
