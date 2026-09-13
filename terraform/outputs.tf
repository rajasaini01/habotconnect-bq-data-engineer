# Candidate: Raja Saini | rajasaini092004@gmail.com
#
# Exposed for downstream consumers, for example the CI/CD pipeline or the
# ingestion Cloud Function's deployment config, so they don't need to
# hardcode resource names that Terraform already knows.

output "d0_bucket_name" {
  description = "Name of the D0 raw landing GCS bucket."
  value       = google_storage_bucket.d0_raw_landing.name
}

output "d0_bucket_url" {
  description = "Fully qualified gs:// URL of the D0 bucket."
  value       = google_storage_bucket.d0_raw_landing.url
}

output "d1_dataset_id" {
  description = "BigQuery dataset ID for the D1 staged/enforced layer."
  value       = google_bigquery_dataset.d1_staged_enforced.dataset_id
}

output "student_onboarding_table_id" {
  description = "Fully qualified table ID for the student_onboarding table."
  value       = "${var.project_id}.${google_bigquery_dataset.d1_staged_enforced.dataset_id}.${google_bigquery_table.student_onboarding.table_id}"
}
