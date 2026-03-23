terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GCS bucket — data lake (raw parquet files)
resource "google_storage_bucket" "data_lake" {
  name          = var.gcs_bucket_name
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

# BigQuery dataset — data warehouse
resource "google_bigquery_dataset" "wildfire" {
  dataset_id            = var.bq_dataset
  location              = var.region
  delete_contents_on_destroy = true
}
