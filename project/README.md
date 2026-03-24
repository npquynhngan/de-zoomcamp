# US Wildfire Analytics Pipeline

An end-to-end batch data engineering project that ingests 28 years of US wildfire occurrence data, loads it into a cloud data warehouse, transforms it with dbt, and surfaces insights through an interactive dashboard.

## Table of Contents

- [Problem Description](#problem-description)
- [Architecture](#architecture)
- [Dashboard](#dashboard)
- [Dataset](#dataset)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Setup Instructions](#setup-instructions)
  - [1. Clone the repository](#1-clone-the-repository)
  - [2. Configure environment variables](#2-configure-environment-variables)
  - [3. Set up GCP service account](#3-set-up-gcp-service-account)
  - [4. Provision GCP infrastructure with Terraform](#4-provision-gcp-infrastructure-with-terraform)
  - [5. Build Docker images](#5-build-docker-images)
  - [6. Run the ingestion pipeline](#6-run-the-ingestion-pipeline)
  - [7. Run dbt transformations](#7-run-dbt-transformations)
  - [8. View the dashboard](#8-view-the-dashboard)
  - [Optional: Orchestrate with Kestra](#optional-orchestrate-with-kestra)
- [Project Structure](#project-structure)
- [Estimated Cloud Costs](#estimated-cloud-costs)
- [Troubleshooting](#troubleshooting)
- [Teardown](#teardown)

---

## Problem Description

Wildfires cause billions of dollars in damage every year across the United States, threatening lives, property, and ecosystems. Understanding where fires occur, when they peak, and what causes them is critical for emergency planners, insurance analysts, and environmental researchers.

This project answers questions such as:
- Which states experience the most fires, and what are the leading causes?
- How has the frequency and severity of wildfires changed over nearly three decades?
- What is the seasonal pattern of wildfire activity?

The pipeline ingests the [FPA FOD (Fire Program Analysis fire-occurrence database)](https://www.kaggle.com/datasets/capcloudcoder/us-wildfire-data-plus-other-attributes), a public dataset of ~2.3 million fire records from 1992 to 2020, maintained by the US Forest Service. Data is stored in Google Cloud Storage, loaded into BigQuery, transformed with dbt, and visualised in Looker Studio.

---

## Architecture

```
┌─────────────────────────────┐
│     Kaggle CSV Dataset       │
│  (FPA FOD, ~2.3 M records)  │
└────────────┬────────────────┘
             │ Kaggle API
             ▼
┌─────────────────────────────┐
│  Python Ingestion (Docker)  │
│  • Download via Kaggle API  │
│  • CSV → Parquet (chunked)  │
│  • Upload to GCS            │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│     Google Cloud Storage    │
│  gs://<bucket>/raw/         │
│  wildfires/*.parquet        │
└────────────┬────────────────┘
             │ BigQuery external load
             ▼
┌─────────────────────────────┐
│   BigQuery — raw_wildfires  │
│  Partitioned: DISCOVERY_DATE│
│  Clustered: STATE, CAUSE    │
└────────────┬────────────────┘
             │ dbt
             ▼
┌─────────────────────────────┐
│      dbt Transformations    │
│  staging/stg_wildfires      │
│    └─ clean, rename, cast   │
│  marts/fct_wildfires        │
│    └─ enriched fact table   │
│  marts/agg_monthly_stats    │
│    └─ monthly counts/acres  │
│  marts/agg_state_stats      │
│    └─ state × cause summary │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│    Looker Studio Dashboard  │
│  • Fire count by cause      │
│  • Monthly trend 1992-2020  │
└─────────────────────────────┘

Infrastructure provisioned by Terraform.
Pipeline orchestrated by Kestra.
```

---

## Dashboard

The Looker Studio dashboard is publicly accessible at:

> **[View Dashboard](https://lookerstudio.google.com)** *(link updated after deployment)*

Screenshot previews:

| Categorical: Fire Count by Cause | Temporal: Monthly Fire Trend |
|---|---|
| ![Fires by cause](dashboard/screenshots/fires_by_cause.png) | ![Monthly trend](dashboard/screenshots/monthly_trend.png) |

See [dashboard/README.md](dashboard/README.md) for step-by-step instructions to recreate the dashboard.

---

## Dataset

| Property | Value |
|----------|-------|
| Name | FPA FOD — US Wildfire Occurrences |
| Source | US Forest Service via Kaggle |
| Kaggle slug | `capcloudcoder/us-wildfire-data-plus-other-attributes` |
| Records | ~2.3 million fires |
| Time range | 1992 – 2020 |
| Key fields | discovery date, containment date, fire size (acres), fire cause, state, county, lat/lon, size class (A–G) |

---

## Technologies Used

| Layer | Tool |
|-------|------|
| Cloud platform | Google Cloud Platform (GCS + BigQuery) |
| Infrastructure as Code | Terraform ≥ 1.6 |
| Containerisation | Docker + Docker Compose |
| Orchestration | Kestra |
| Data ingestion | Python (pandas, pyarrow, google-cloud-storage) |
| Transformations | dbt (dbt-bigquery) |
| Dashboard | Looker Studio |

---

## Prerequisites

Before you begin, make sure the following tools are installed and configured:

- [GCP account](https://cloud.google.com/) with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated (`gcloud auth login`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2
- [Kaggle account](https://www.kaggle.com/) — generate an API token at **Settings → API → Create New Token**

---

## Quick Start

If you already have all prerequisites in place, the full pipeline can be run with:

```bash
git clone https://github.com/npquynhngan/de-zoomcamp.git
cd de-zoomcamp/project

make setup          # create .env from template
# Edit .env with your GCP and Kaggle credentials

make tf-init && make tf-apply   # provision GCS + BigQuery
make build                      # build Docker images
make pipeline                   # ingest + dbt run + dbt test
```

See the detailed [Setup Instructions](#setup-instructions) below for a step-by-step walkthrough.

---

## Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/npquynhngan/de-zoomcamp.git
cd de-zoomcamp/project
```

### 2. Configure environment variables

```bash
make setup          # copies .env.example -> .env
```

Open `.env` and fill in all values:

```dotenv
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=us-central1
GCS_BUCKET_NAME=your-gcp-project-id-wildfire-data-lake
BQ_DATASET=wildfire_data

# Absolute path to your GCP service account JSON key (created in step 3)
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/your/gcp-key.json

# Kaggle API token — from https://www.kaggle.com/settings → API → Create New Token
KAGGLE_API_TOKEN=KGAT_your_token_here
```

> **Note:** Never commit `.env` to version control. It is already listed in `.gitignore`.

### 3. Set up GCP service account

```bash
export GCP_PROJECT_ID=your-gcp-project-id

# Create a dedicated service account
gcloud iam service-accounts create wildfire-pipeline \
  --description="Wildfire pipeline service account" \
  --display-name="Wildfire Pipeline" \
  --project=$GCP_PROJECT_ID

# Grant Storage and BigQuery admin roles
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

Copy the provided example and fill in your values:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
project_id      = "your-gcp-project-id"
region          = "us-central1"
gcs_bucket_name = "your-gcp-project-id-wildfire-data-lake"
bq_dataset      = "wildfire_data"
```

Then initialise and apply:

```bash
make tf-init
make tf-apply
```

This provisions:
- A GCS bucket for the data lake (`raw/wildfires/`)
- A BigQuery dataset (`wildfire_data`)

### 5. Build Docker images

```bash
make build
```

This builds the ingestion and dbt Docker images defined in `docker/docker-compose.yaml`.

### 6. Run the ingestion pipeline

```bash
make ingest
```

The ingestion container will:
1. Download the wildfire CSV from Kaggle using your API token
2. Convert it to Parquet files in 100 000-row chunks
3. Upload the Parquet files to GCS under `gs://<bucket>/raw/wildfires/`
4. Load them into a partitioned + clustered BigQuery table (`raw_wildfires`)

Expected result: ~2.3 million rows in `wildfire_data.raw_wildfires`.

### 7. Run dbt transformations

```bash
make dbt-run     # materialise staging + mart models
make dbt-test    # run schema and data quality tests
```

Or run ingestion and transformations in a single command:

```bash
make pipeline
```

The dbt models created are:

| Model | Type | Description |
|-------|------|-------------|
| `staging.stg_wildfires` | View | Cleans and renames raw columns, casts types |
| `marts.fct_wildfires` | Table | Enriched fact table with derived fields |
| `marts.agg_monthly_stats` | Table | Monthly fire count and total acres |
| `marts.agg_state_stats` | Table | Fire count and acres by state and cause |

### 8. View the dashboard

1. Open [Looker Studio](https://lookerstudio.google.com)
2. Create a new report and connect to BigQuery
3. Select your project → `wildfire_data` → `agg_monthly_stats` (for the temporal tile)
4. Add a second data source: `agg_state_stats` (for the categorical tile)
5. See [dashboard/README.md](dashboard/README.md) for full step-by-step chart configuration

### Optional: Orchestrate with Kestra

Kestra provides a scheduled, observable alternative to running `make pipeline` manually.

```bash
make kestra-up
```

Open `http://localhost:8080`, navigate to **Flows**, and either:
- Trigger `wildfire_pipeline` manually, or
- Enable the built-in daily schedule.

To stop Kestra:

```bash
make kestra-down
```

---

## Project Structure

```
project/
├── README.md                          # This file
├── Makefile                           # Convenience make targets
├── .env.example                       # Environment variable template
├── terraform/
│   ├── main.tf                        # GCS bucket + BigQuery dataset
│   ├── variables.tf                   # Input variable declarations
│   ├── outputs.tf                     # Output values
│   └── terraform.tfvars.example       # tfvars template (copy to terraform.tfvars)
├── docker/
│   ├── docker-compose.yaml            # Ingestion + dbt services
│   ├── ingestion/
│   │   ├── Dockerfile
│   │   ├── pyproject.toml
│   │   └── ingest.py                  # Kaggle → GCS → BigQuery pipeline
│   └── dbt/
│       └── Dockerfile
├── kestra/
│   ├── docker-compose.yaml            # Kestra server + worker
│   └── flows/
│       └── wildfire_pipeline.yaml     # Full orchestration flow
├── dbt_wildfire/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_wildfires.sql      # Clean + rename raw columns
│   │   │   └── schema.yml
│   │   └── marts/
│   │       ├── fct_wildfires.sql      # Enriched fact table
│   │       ├── agg_monthly_stats.sql  # Monthly aggregates
│   │       ├── agg_state_stats.sql    # State × cause aggregates
│   │       └── schema.yml
│   └── macros/
│       └── fire_size_class.sql        # Fire size class label macro
└── dashboard/
    ├── README.md                      # Dashboard recreation guide
    └── screenshots/
```

---

## Estimated Cloud Costs

All resources fall within the GCP free tier for this dataset size:

| Resource | Free tier | Estimated usage |
|----------|-----------|----------------|
| BigQuery storage | 10 GB / month | ~1 GB |
| BigQuery queries | 1 TB / month | < 10 GB |
| GCS storage | 5 GB / month | ~500 MB |

Expected monthly cost: **$0** (within free tier).

---

## Troubleshooting

**`make ingest` fails with `401 Unauthorized` from Kaggle**
- Confirm `KAGGLE_API_TOKEN` in `.env` is correct and has not expired.
- Re-generate the token at [kaggle.com/settings](https://www.kaggle.com/settings) → API → Create New Token.

**`make tf-apply` fails with permission errors**
- Ensure the service account has `roles/storage.admin` and `roles/bigquery.admin`.
- Verify `GOOGLE_APPLICATION_CREDENTIALS` points to the correct JSON key file.
- Run `gcloud auth application-default login` if using personal credentials locally.

**`make dbt-run` fails with `Dataset not found`**
- The ingestion step must complete successfully before dbt runs (`raw_wildfires` must exist).
- Confirm `BQ_DATASET` and `GCP_PROJECT_ID` in `.env` match the values used in Terraform.

**Docker containers cannot access `.env`**
- Make sure `.env` exists in `project/` (run `make setup` if it does not).
- The `docker-compose.yaml` mounts `.env` as environment — do not rename the file.

**Kestra UI is not reachable at `http://localhost:8080`**
- Confirm containers started: `docker compose -f kestra/docker-compose.yaml ps`
- Check logs: `docker compose -f kestra/docker-compose.yaml logs`

---

## Teardown

To remove all GCP resources provisioned by Terraform:

```bash
make tf-destroy
```

To stop and remove local Docker containers and volumes:

```bash
make clean
```
