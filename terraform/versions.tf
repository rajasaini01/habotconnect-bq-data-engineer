# Candidate: Raja Saini | rajasaini092004@gmail.com
#
# Pin provider and Terraform versions so `terraform init` is reproducible across
# machines. Unpinned versions are a common source of "works on my machine" drift.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
