# The Primary GKE Standard Cluster
resource "google_container_cluster" "primary" {
  name     = "esg-standard-cluster"
  location = var.zone

  # Remove the default node pool upon creation (Best Practice for Standard GKE)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network Configuration
  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.private.name

  # Enable VPC-native cluster (required for modern GKE and Private Clusters)
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pod-range"
    services_secondary_range_name = "gke-service-range"
  }

  # Make it a Private Cluster to demonstrate architecture security
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep endpoint public for easy kubectl access in lab
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
  # Deletion protection is true by default in Terraform provider, set to false for lab explicitly
  deletion_protection = false
}

# A custom Node Pool specifically designed for our workloads
resource "google_container_node_pool" "primary_nodes" {
  name       = "esg-core-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2 # Fixed size for this simple pool, though autoscaling is common

  node_config {
    preemptible  = true     # Save cost in Sandbox! Extensively asked in interviews for FinOps.
    machine_type = "e2-medium"

    # Define Service Account scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only", # Required to pull from Artifact Registry
    ]
  }
}
