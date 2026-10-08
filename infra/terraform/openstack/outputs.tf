output "k3s_node_ip" {
  description = "Public Floating IP of the k3s node"
  value       = openstack_networking_floatingip_v2.k8s_fip.address
}

output "k3s_internal_ip" {
  description = "Internal IP of the k3s node"
  value       = openstack_compute_instance_v2.k3s_node.access_ip_v4
}

output "api_endpoint" {
  description = "Demo API Ingress URL"
  value       = "http://demo.${openstack_networking_floatingip_v2.k8s_fip.address}.nip.io"
}

output "grafana_endpoint" {
  description = "Grafana Dashboard Ingress URL"
  value       = "http://grafana.${openstack_networking_floatingip_v2.k8s_fip.address}.nip.io"
}
