variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "devops-prime-499411"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "demo-gke-cluster"
}

variable "node_count" {
  description = "Nodes per zone"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "demo"
}
