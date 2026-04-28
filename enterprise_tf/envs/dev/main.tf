terraform {
  backend "gcs" {
    bucket  = "tf-state-project-ba42a5bc-01e3-4ef3-ab9"
    prefix  = "terraform/state/dev"
  }
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "network" {
  source       = "../../modules/network"
  region       = var.region
  network_name = "esg-dev-vpc"
}

module "gke" {
  source       = "../../modules/gke"
  zone         = var.zone
  cluster_name = "esg-dev-cluster"
  network_name = module.network.network_name
  subnet_name  = module.network.subnet_name
  node_count   = 1 # Dev environment optimization
  preemptible  = true
}
