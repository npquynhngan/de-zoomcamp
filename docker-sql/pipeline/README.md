# Pipeline

Ingest NYC Yellow Taxi data into Postgres and explore it from a Jupyter notebook. The notebook reads the CSV from the DataTalksClub release, creates a table schema, and loads the data in chunks.

## What it does
- Downloads `yellow_tripdata_2021-01.csv.gz` from GitHub.
- Reads the file with explicit dtypes and parsed timestamps.
- Creates the `yellow_taxi_data` table from the DataFrame schema.
- Appends data in chunks to avoid memory spikes.

## Requirements
- Python 3.13+
- Postgres running and reachable (default: `localhost:5432`).
- Dependencies from `pyproject.toml` (pandas, sqlalchemy, psycopg2-binary, tqdm).

## Files
- `notebook.ipynb`: primary workflow for loading data into Postgres.
- `pipeline.py`: small CLI example that writes a Parquet file.
- `main.py`: minimal entry-point example.
- `pyproject.toml`: dependencies and project metadata.
- `Dockerfile`: container build scaffold.

## Quickstart
1. Install dependencies using your preferred Python environment tool.
2. Start Postgres and create a database called `ny_taxi`.
3. Open `notebook.ipynb` and run cells in order.

## Connection string
The notebook uses this connection string by default:

```
postgresql://root:root@localhost:5432/ny_taxi
```

Update it if your credentials or host differ.

## Notes
- The table is created with `if_exists='replace'`, which drops and recreates it.
- If you see `relation "test" already exists` in psql, use:

```
DROP TABLE IF EXISTS test;
```
