variable "subnet_cidr" {
  description = "Internal subnet CIDR"
  type        = string
  default     = "10.17.3.0/24"
}

variable "external_network_id" {
  description = "ID of external provider network"
  type        = string
  default     = "public-network-id"
}

variable "floating_ip_pool" {
  description = "Floating IP pool name"
  type        = string
  default     = "public"
}

variable "image_name" {
  description = "Ubuntu 22.04 LTS cloud image name"
  type        = string
  default     = "Ubuntu-22.04"
}

variable "flavor_name" {
  description = "VM flavor (4 vCPU, 8 GB RAM recommended)"
  type        = string
  default     = "m1.large"
}

variable "key_pair_name" {
  description = "OpenStack SSH keypair name"
  type        = string
  default     = "devops-key"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "admin_cidr" {
  description = "Admin IP range allowed to access SSH and K8s API (0.0.0.0/0 forbidden)"
  type        = string
  default     = "127.0.0.1/32"

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "Security policy violation: admin_cidr cannot be open to 0.0.0.0/0."
  }
}
