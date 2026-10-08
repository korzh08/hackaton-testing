terraform {
  required_version = ">= 1.5.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

provider "openstack" {
  # Configuration read from standard OS_* environment variables (e.g. source openrc.sh)
}

resource "openstack_networking_network_v2" "k8s_network" {
  name           = "mts-k8s-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name            = "mts-k8s-subnet"
  network_id      = openstack_networking_network_v2.k8s_network.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = ["77.88.8.8", "8.8.8.8"]
}

resource "openstack_networking_router_v2" "k8s_router" {
  name                = "mts-k8s-router"
  admin_state_up      = true
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "k8s_router_iface" {
  router_id = openstack_networking_router_v2.k8s_router.id
  subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
}

resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "mts-k8s-secgroup"
  description = "Security group for production k3s cluster"
}

# SSH access restricted to admin CIDR
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Kubernetes API restricted to admin CIDR
resource "openstack_networking_secgroup_rule_v2" "k8s_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# HTTP / HTTPS public ingress
resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_compute_instance_v2" "k3s_node" {
  name            = "mts-k3s-node-1"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.key_pair_name
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  user_data = templatefile("${path.module}/../cloud-init/user-data.yaml", {
    ssh_public_key = file(var.public_key_path)
  })

  network {
    uuid = openstack_networking_network_v2.k8s_network.id
  }
}

resource "openstack_networking_floatingip_v2" "k8s_fip" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "k8s_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.k8s_fip.address
  instance_id = openstack_compute_instance_v2.k3s_node.id
}
