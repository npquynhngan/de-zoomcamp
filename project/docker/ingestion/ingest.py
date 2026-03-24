#!/usr/bin/env python
"""
Wildfire data ingestion pipeline.

Downloads the FPA FOD wildfire dataset from Kaggle, converts to Parquet,
uploads to GCS (data lake), then loads into a partitioned BigQuery table.
"""

import os
import subprocess
import tempfile
from pathlib import Path

import click
import pandas as pd
from google.cloud import bigquery, storage
from tqdm import tqdm

# Column dtypes for the FW_Veg_Rem_Combined wildfire dataset
DTYPE = {
    "fire_name": "string",
    "fire_size": "float64",
    "fire_size_class": "string",
    "stat_cause_descr": "string",
    "latitude": "float64",
    "longitude": "float64",
    "state": "string",
    "discovery_month": "string",
    "putout_time": "float64",
    "disc_pre_year": "Int64",
    "disc_pre_month": "Int64",
    "wstation_usaf": "string",
    "dstation_m": "float64",
    "wstation_wban": "string",
    "wstation_byear": "Int64",
    "wstation_eyear": "Int64",
    "Vegetation": "string",
    "fire_mag": "float64",
    "weather_file": "string",
    "Temp_pre_30": "float64",
    "Temp_pre_15": "float64",
    "Temp_pre_7": "float64",
    "Temp_cont": "float64",
    "Wind_pre_30": "float64",
    "Wind_pre_15": "float64",
    "Wind_pre_7": "float64",
    "Wind_cont": "float64",
    "Hum_pre_30": "float64",
    "Hum_pre_15": "float64",
    "Hum_pre_7": "float64",
    "Hum_cont": "float64",
    "Prec_pre_30": "float64",
    "Prec_pre_15": "float64",
    "Prec_pre_7": "float64",
    "Prec_cont": "float64",
    "remoteness": "float64",
}

PARSE_DATES = ["disc_clean_date", "cont_clean_date", "disc_date_final", "cont_date_final", "disc_date_pre"]

CHUNK_SIZE = 100_000


def download_kaggle_dataset(dataset: str, dest_dir: Path) -> Path:
    """Download a Kaggle dataset and return the path to the extracted CSV file."""
    print(f"Downloading Kaggle dataset: {dataset}")
    subprocess.run(
        ["kaggle", "datasets", "download", "-d", dataset, "-p", str(dest_dir), "--unzip"],
        check=True,
    )
    csv_files = list(dest_dir.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No CSV files found in {dest_dir} after download")
    # Pick the largest CSV (the main data file)
    return max(csv_files, key=lambda p: p.stat().st_size)


def csv_to_parquet(csv_path: Path, parquet_dir: Path) -> list[Path]:
    """Convert a large CSV to chunked Parquet files."""
    parquet_dir.mkdir(parents=True, exist_ok=True)
    parquet_files = []

    df_iter = pd.read_csv(
        csv_path,
        dtype=DTYPE,
        parse_dates=PARSE_DATES,
        iterator=True,
        chunksize=CHUNK_SIZE,
        low_memory=False,
    )

    for i, chunk in enumerate(tqdm(df_iter, desc="Converting to Parquet")):
        out_path = parquet_dir / f"part_{i:05d}.parquet"
        chunk.to_parquet(out_path, index=False, engine="pyarrow")
        parquet_files.append(out_path)

    print(f"Wrote {len(parquet_files)} Parquet file(s) to {parquet_dir}")
    return parquet_files


def upload_to_gcs(parquet_files: list[Path], bucket_name: str, gcs_prefix: str) -> list[str]:
    """Upload Parquet files to GCS and return list of GCS URIs."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    gcs_uris = []

    for local_path in tqdm(parquet_files, desc="Uploading to GCS"):
        blob_name = f"{gcs_prefix}/{local_path.name}"
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(str(local_path))
        uri = f"gs://{bucket_name}/{blob_name}"
        gcs_uris.append(uri)
        print(f"  Uploaded: {uri}")

    return gcs_uris


def create_bq_table(
    project_id: str,
    dataset_id: str,
    table_id: str,
    bucket_name: str,
    gcs_prefix: str,
) -> None:
    """Load Parquet files from GCS into a partitioned, clustered BigQuery table."""
    client = bigquery.Client(project=project_id)
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"

    # Drop and recreate raw table
    client.delete_table(full_table_id, not_found_ok=True)
    print(f"Creating BigQuery table: {full_table_id}")

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="disc_clean_date",
        ),
        clustering_fields=["state", "stat_cause_descr"],
    )

    gcs_uri = f"gs://{bucket_name}/{gcs_prefix}/*.parquet"
    load_job = client.load_table_from_uri(gcs_uri, full_table_id, job_config=job_config)
    print(f"Loading from {gcs_uri} ...")
    load_job.result()  # Wait for job to complete

    table = client.get_table(full_table_id)
    print(f"Loaded {table.num_rows:,} rows into {full_table_id}")
    print(f"  Partitioned by: disc_clean_date (DAY)")
    print(f"  Clustered by: state, stat_cause_descr")


@click.command()
@click.option("--project-id", envvar="GCP_PROJECT_ID", required=True, help="GCP project ID")
@click.option("--bucket-name", envvar="GCS_BUCKET_NAME", required=True, help="GCS bucket name")
@click.option("--dataset-id", envvar="BQ_DATASET", default="wildfire_data", show_default=True)
@click.option("--table-id", default="raw_wildfires", show_default=True)
@click.option("--gcs-prefix", default="raw/wildfires", show_default=True)
@click.option(
    "--kaggle-dataset",
    default="capcloudcoder/us-wildfire-data-plus-other-attributes",
    show_default=True,
    help="Kaggle dataset slug (owner/dataset-name)",
)
@click.option("--work-dir", default="/tmp/wildfire", show_default=True, help="Local working directory")
def run(project_id, bucket_name, dataset_id, table_id, gcs_prefix, kaggle_dataset, work_dir):
    """Download wildfire data, upload to GCS, and load into BigQuery."""
    work_path = Path(work_dir)
    raw_dir = work_path / "raw"
    parquet_dir = work_path / "parquet"
    raw_dir.mkdir(parents=True, exist_ok=True)

    # Step 1: Download from Kaggle
    csv_path = download_kaggle_dataset(kaggle_dataset, raw_dir)
    print(f"Dataset downloaded to: {csv_path}")

    # Step 2: Convert to Parquet chunks
    parquet_files = csv_to_parquet(csv_path, parquet_dir)

    # Step 3: Upload to GCS
    upload_to_gcs(parquet_files, bucket_name, gcs_prefix)

    # Step 4: Load into BigQuery (partitioned + clustered)
    create_bq_table(project_id, dataset_id, table_id, bucket_name, gcs_prefix)

    print("\nIngestion complete!")


if __name__ == "__main__":
    run()
