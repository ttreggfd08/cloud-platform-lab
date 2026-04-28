terraform {
  # 加上這段，指定遠端狀態的存放位置
  backend "gcs" {
    bucket  = "tf-state-project-ba42a5bc-01e3-4ef3-ab9"
    prefix  = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
