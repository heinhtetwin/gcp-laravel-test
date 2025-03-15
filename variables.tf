variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "cool-bay-433704-s9"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "db_password" {
  description = "Cloud SQL user password"
  default     = "password"
  type        = string
  sensitive   = true
}
