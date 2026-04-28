variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP Region"
}

variable "zone" {
  type        = string
  default     = "us-central1-b"
  description = "The GCP Zone"
}
