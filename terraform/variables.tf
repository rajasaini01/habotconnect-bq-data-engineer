# Candidate: Raja Saini | rajasaini092004@gmail.com
#
# Environment-specific values live here, not hardcoded in main.tf.

variable "project_id" {
  description = "GCP project ID to provision resources into. No default on purpose — this forces an explicit value at plan/apply time instead of silently applying to the wrong project."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources. Defaults to Mumbai (asia-south1) — see ASSUMPTIONS.md item 3."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment label, used for resource naming and cost tracking. One of: staging, production."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either \"staging\" or \"production\"."
  }
}

variable "bq_admin_group" {
  description = "Google Group email that receives BigQuery admin (roles/bigquery.admin) access to the D1 dataset. Least-privilege: individual users are never bound directly."
  type        = string
  default     = "gcp-bq-admins@habotconnect.com"
}

variable "bq_analyst_group" {
  description = "Google Group email that receives read-only, row-restricted access to the D1 dataset."
  type        = string
  default     = "gcp-bq-analysts@habotconnect.com"
}

variable "pii_reader_group" {
  description = "Google Group email authorized to view unmasked PII columns (parent contact details, student name) in D1."
  type        = string
  default     = "gcp-pii-readers@habotconnect.com"
}

variable "ingestion_service_account_email" {
  description = "Service account used by the Cloud Function / Pub/Sub ingestion pipeline to write raw payloads into the D0 bucket. No default — this is project-specific and must be supplied explicitly, for example sa-onboarding-ingestion@<project_id>.iam.gserviceaccount.com."
  type        = string
}
