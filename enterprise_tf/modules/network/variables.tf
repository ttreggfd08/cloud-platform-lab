variable "region" {}
variable "network_name" { default = "esg-gke-vpc" }
variable "subnet_cidr" { default = "10.0.0.0/18" }
variable "pod_cidr" { default = "10.48.0.0/14" }
variable "service_cidr" { default = "10.52.0.0/20" }
