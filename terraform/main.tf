# Task 1 — Secure Staging Provisioning
# Candidate: Raja Saini | rajasaini092004@gmail.com
#
# D0 (raw landing bucket) + D1 (staged/enforced BigQuery dataset) for the
# student onboarding pipeline, with least-privilege IAM and row/column
# security.

# --- D0: Raw Landing (GCS) ---------------------------------------------
# Raw payloads land here before validation. Kept separate from D1 so a bad
# ingest never touches the enforced layer, and raw data can be replayed.
resource "google_storage_bucket" "d0_raw_landing" {
  name     = "${var.project_id}-d0-raw-landing"
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    environment = var.environment
    data_layer  = "d0-raw"
    managed_by  = "terraform"
  }
}

# Ingestion SA can only create objects — never delete/read/manage the bucket.
resource "google_storage_bucket_iam_member" "d0_ingestion_writer" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.ingestion_service_account_email}"
}

# --- D1: Staged / Enforced (BigQuery) -----------------------------------
resource "google_bigquery_dataset" "d1_staged_enforced" {
  dataset_id  = "d1_staged_enforced"
  project     = var.project_id
  location    = var.region
  description = "Staged and schema-enforced student onboarding data. Populated only from validated D0 records."

  # Persistent warehouse layer, not scratch — tables shouldn't expire.
  default_table_expiration_ms = null

  labels = {
    environment = var.environment
    data_layer  = "d1-staged-enforced"
    managed_by  = "terraform"
  }
}

# Bound to groups, not individuals, so access survives personnel changes.
resource "google_bigquery_dataset_iam_member" "d1_admin" {
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataOwner"
  member     = "group:${var.bq_admin_group}"
}

# Read-only at IAM level; row access policy below restricts which rows.
resource "google_bigquery_dataset_iam_member" "d1_analyst_reader" {
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "group:${var.bq_analyst_group}"
}

# --- Column-level security (PII masking) --------------------------------
resource "google_data_catalog_taxonomy" "pii_taxonomy" {
  project                = var.project_id
  region                 = var.region
  display_name           = "habotconnect-pii-taxonomy"
  description            = "Classifies columns containing personally identifiable information for the student onboarding dataset."
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "pii_policy_tag" {
  taxonomy     = google_data_catalog_taxonomy.pii_taxonomy.id
  display_name = "pii-restricted"
  description  = "Applied to columns holding parent/student contact or identity details. Unmasked access limited to the PII reader group."
}

resource "google_data_catalog_policy_tag_iam_member" "pii_reader" {
  policy_tag = google_data_catalog_policy_tag.pii_policy_tag.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = "group:${var.pii_reader_group}"
}

# --- student_onboarding table -------------------------------------------
# Schema mirrors data_pipeline/models.py.
resource "google_bigquery_table" "student_onboarding" {
  dataset_id          = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id            = "student_onboarding"
  project             = var.project_id
  deletion_protection = true

  time_partitioning {
    type  = "DAY"
    field = "onboarding_date"
  }

  clustering = ["lsa_region"]

  schema = jsonencode([
    {
      name = "student_full_name"
      type = "STRING"
      mode = "REQUIRED"
      policyTags = {
        names = [google_data_catalog_policy_tag.pii_policy_tag.id]
      }
    },
    {
      name = "parent_email"
      type = "STRING"
      mode = "REQUIRED"
      policyTags = {
        names = [google_data_catalog_policy_tag.pii_policy_tag.id]
      }
    },
    {
      name = "parent_phone"
      type = "STRING"
      mode = "REQUIRED"
      policyTags = {
        names = [google_data_catalog_policy_tag.pii_policy_tag.id]
      }
    },
    {
      name = "date_of_birth"
      type = "DATE"
      mode = "REQUIRED"
    },
    {
      name = "lsa_region"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "onboarding_date"
      type = "DATE"
      mode = "REQUIRED"
    },
    {
      name        = "consent_data_processing"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "DCYN field. Allowed values: YES, NO only."
    },
    {
      name        = "diagnosed_learning_need"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "DCYN field. Allowed values: YES, NO only."
    },
    {
      name        = "requires_financial_assistance"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "DCYN field. Allowed values: YES, NO only."
    },
    {
      name        = "lsa_previously_assigned"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "DCYN field. Allowed values: YES, NO only."
    },
    {
      name = "additional_notes"
      type = "STRING"
      mode = "NULLABLE"
    }
  ])

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# --- Row-level security ---------------------------------------------------
# Analysts only see rows for their assigned LSA region. authorized_viewers
# maps each analyst's email to the region they're cleared for. Row access
# policies aren't yet a native google_bigquery_* resource, so this is
# applied via local-exec calling the bq CLI (Google's documented approach).
resource "google_bigquery_table" "authorized_viewers" {
  dataset_id          = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id            = "authorized_viewers"
  project             = var.project_id
  deletion_protection = true

  schema = jsonencode([
    {
      name = "viewer_email"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "region"
      type = "STRING"
      mode = "REQUIRED"
    }
  ])

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "null_resource" "row_access_policy" {
  depends_on = [
    google_bigquery_table.student_onboarding,
    google_bigquery_table.authorized_viewers,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      bq query --use_legacy_sql=false \
        "CREATE OR REPLACE ROW ACCESS POLICY analyst_region_restriction
         ON \`${var.project_id}.d1_staged_enforced.student_onboarding\`
         GRANT TO ('group:${var.bq_analyst_group}')
         FILTER USING (
           lsa_region IN (
             SELECT region FROM \`${var.project_id}.d1_staged_enforced.authorized_viewers\`
             WHERE viewer_email = SESSION_USER()
           )
         )"
    EOT
  }
}
