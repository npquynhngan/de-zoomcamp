# US Wildfire Analytics Pipeline

An end-to-end batch data engineering project that ingests 28 years of US wildfire occurrence data, loads it into a cloud data warehouse, transforms it with dbt, and surfaces insights through an interactive dashboard.

## Problem Description

Wildfires cause billions of dollars in damage every year across the United States, threatening lives, property, and ecosystems. Understanding where fires occur, when they peak, and what causes them is critical for emergency planners, insurance analysts, and environmental researchers.

This project answers questions such as:
- Which states experience the most fires, and what are the leading causes?
- How has the frequency and severity of wildfires changed over nearly three decades?
- What is the seasonal pattern of wildfire activity?

The pipeline ingests the [FPA FOD (Fire Program Analysis fire-occurrence database)](https://www.kaggle.com/datasets/capcloudcoder/us-wildfire-data-plus-other-attributes), a public dataset of ~2.3 million fire records from 1992 to 2020, maintained by the US Forest Service. Data is stored in Google Cloud Storage, loaded into BigQuery, transformed with dbt, and visualised in Looker Studio.

## Architecture

```
[Kaggle CSV Dataset]
       |
       v
[Python Ingestion Script (Docker)]
  - Download from Kaggle API
  - Convert CSV -> Parquet (chunked)
  - Upload to GCS (data lake)
       |
       v
[Google Cloud Storage]
  gs://<bucket>/raw/wildfires/
       |
       v
[BigQuery - raw_wildfires]
  Partitioned by DISCOVERY_DATE (day)
  Clustered by STATE, NWCG_GENERAL_CAUSE
       |
       v
[dbt Transformations]
  staging/stg_wildfires     - clean, rename, type-cast
  marts/fct_wildfires       - enriched fact table
  marts/agg_monthly_stats   - monthly fire counts/acreage
  marts/agg_state_stats     - state x cause aggregates
       |
       v
[Looker Studio Dashboard]
  Tile 1: Fire count by cause (categorical bar chart)
  Tile 2: Monthly fire trend 1992-2020 (temporal line chart)

Infrastructure provisioned by Terraform. Pipeline orchestrated by Kestra.
```

## Dashboard

The Looker Studio dashboard is publicly accessible at:

> **[View Dashboard](https://lookerstudio.google.com)** *(link updated after deployment)*

Screenshot previews:

| Categorical: Fire Count by Cause | Temporal: Monthly Fire Trend |
|---|---|
| ![Fires by cause](dashboard/screenshots/fires_by_cause.png) | ![Monthly trend](dashboard/screenshots/monthly_trend.png) |

See [dashboard/README.md](dashboard/README.md) for instructions to recreate the dashboard.

## Dataset

| Property | Value |
|----------|-------|
| Name | FPA FOD - US Wildfire Occurrences |
| Source | US Forest Service via Kaggle |
| Kaggle slug | `capcloudcoder/us-wildfire-data-plus-other-attributes` |
| Records | ~2.3 million fires |
| Time range | 1992 - 2020 |
| Key fields | discovery date, containment date, fire size (acres), fire cause, state, county, lat/lon, size class (A-G) |

## Technologies Used

| Layer | Tool |
|-------|------|
| Cloud platform | Google Cloud Platform (GCS + BigQuery) |
| Infrastructure as Code | Terraform |
| Containerisation | Docker + Docker Compose |
| Orchestration | Kestra |
| Data ingestion | Python (pandas, pyarrow, google-cloud-storage) |
| Transformations | dbt (dbt-bigquery) |
| Dashboard | Looker Studio |

## Prerequisites

- [GCP account](https://cloud.google.com/) with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [Kaggle account](https://www.kaggle.com/) with an API key

## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/npquynhngan/de-zoomcamp.git
cd de-zoomcamp/project
```

### 2. Configure environment variables

```bash
make setup          # copies .env.example to .env
```

Edit `.env` and fill in all values:

```
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=us-central1
GCS_BUCKET_NAME=your-project-id-wildfire-data-lake
BQ_DATASET=wildfire_data
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/gcp-key.json
KAGGLE_USERNAME=your-kaggle-username
KAGGLE_KEY=your-kaggle-api-key
```

### 3. Set up GCP service account

```bash
# Create a service account
gcloud iam service-accounts create wildfire-pipeline \
  --description="Wildfire pipeline service account" \
  --display-name="Wildfire Pipeline"

# Grant required roles
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:wildfire-pipeline@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:wildfire-pipeline@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"

# Download the JSON key
gcloud iam service-accounts keys create ~/wildfire-gcp-key.json \
  --iam-account wildfire-pipeline@$GCP_PROJECT_ID.iam.gserviceaccount.com
```

Set `GOOGLE_APPLICATION_CREDENTIALS=~/wildfire-gcp-key.json` in your `.env`.

### 4. Provision GCP infrastructure with Terraform

Create `terraform/terraform.tfvars`:

```hcl
project_id      = "your-gcp-project-id"
gcs_bucket_name = "your-project-id-wildfire-data-lake"
bq_dataset      = "wildfire_data"
region          = "us-central1"
```

Then run:

```bash
make tf-init
make tf-apply
```

This provisions:
- A GCS bucket for the data lake
- A BigQuery dataset (`wildfire_data`)

### 5. Build Docker images

```bash
make build
```

### 6. Run the ingestion pipeline

```bash
make ingest
```

This:
1. Downloads the wildfire CSV from Kaggle
2. Converts it to Parquet files in 100k-row chunks
3. Uploads the Parquet files to GCS
4. Loads them into a partitioned + clustered BigQuery table (`raw_wildfires`)

Expected result: ~2.3 million rows in `wildfire_data.raw_wildfires`.

### 7. Run dbt transformations

```bash
make dbt-run     # create staging + mart models
make dbt-test    # run data quality tests
```

Or run everything in sequence:

```bash
make pipeline
```

### 8. View the dashboard

1. Open [Looker Studio](https://lookerstudio.google.com)
2. Create a new report and connect to BigQuery
3. Select your project -> `wildfire_data` -> `agg_monthly_stats` (for temporal tile)
4. Add a second data source: `agg_state_stats` (for categorical tile)
5. See [dashboard/README.md](dashboard/README.md) for full step-by-step instructions

### Optional: Orchestrate with Kestra

```bash
make kestra-up
```

Open `http://localhost:8080`, navigate to Flows, and trigger `wildfire_pipeline` manually or enable the daily schedule.

## Project Structure

```
project/
├── README.md                        # This file
├── Makefile                         # Convenience targets
├── .env.example                     # Environment variable template
├── terraform/
│   ├── main.tf                      # GCS bucket + BigQuery dataset
│   ├── variables.tf
│   └── outputs.tf
├── docker/
│   ├── docker-compose.yaml          # Ingestion + dbt services
│   ├── ingestion/
│   │   ├── Dockerfile
│   │   ├── pyproject.toml
│   │   └── ingest.py                # Kaggle -> GCS -> BigQuery pipeline
│   └── dbt/
│       └── Dockerfile
├── kestra/
│   ├── docker-compose.yaml          # Kestra server + worker
│   └── flows/
│       └── wildfire_pipeline.yaml   # Full orchestration flow
├── dbt_wildfire/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_wildfires.sql    # Clean + rename raw columns
│   │   │   └── schema.yml
│   │   └── marts/
│   │       ├── fct_wildfires.sql    # Enriched fact table
│   │       ├── agg_monthly_stats.sql
│   │       ├── agg_state_stats.sql
│   │       └── schema.yml
│   └── macros/
│       └── fire_size_class.sql      # Size class label macro
└── dashboard/
    ├── README.md                    # Dashboard recreation guide
    └── screenshots/
```

## Estimated Cloud Costs

All resources are within GCP free tier limits for this dataset size:

| Resource | Free tier | Estimated usage |
|----------|-----------|----------------|
| BigQuery storage | 10 GB/month free | ~1 GB |
| BigQuery queries | 1 TB/month free | < 10 GB |
| GCS storage | 5 GB/month free | ~500 MB |

Expected monthly cost: **$0** (within free tier).

## Teardown

To remove all GCP resources:

```bash
make tf-destroy
```
