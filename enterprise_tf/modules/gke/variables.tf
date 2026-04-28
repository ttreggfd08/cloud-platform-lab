variable "zone" {}
variable "cluster_name" {}
variable "network_name" {}
variable "subnet_name" {}
variable "master_ipv4_cidr_block" { default = "172.16.0.0/28" }
variable "node_count" { default = 2 }
variable "machine_type" { default = "e2-medium" }
variable "preemptible" { default = true }
