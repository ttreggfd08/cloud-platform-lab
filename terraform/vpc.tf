# Create a Custom VPC Network (Best Practice: Never use the 'default' VPC)
resource "google_compute_network" "main" {
  name                    = "esg-gke-vpc"
  auto_create_subnetworks = false
}

# Create a Subnet exclusively for GKE
resource "google_compute_subnetwork" "private" {
  name                     = "esg-gke-subnet"
  ip_cidr_range            = "10.0.0.0/18"
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pod-range"
    ip_cidr_range = "10.48.0.0/14"
  }

  secondary_ip_range {
    range_name    = "gke-service-range"
    ip_cidr_range = "10.52.0.0/20"
  }
}

# Create Cloud Router and NAT for private nodes to access internet (e.g., pulling images)
resource "google_compute_router" "router" {
  name    = "esg-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "esg-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
