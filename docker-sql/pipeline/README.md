# Pipeline

Simple example pipeline that accepts a month argument, builds a tiny pandas DataFrame, and writes a Parquet file.

## What it does
- Reads a month number from the first CLI argument.
- Creates a sample DataFrame with `day` and `num_passengers`.
- Adds a `month` column.
- Writes the result to `output_month_<month>.parquet`.

## Requirements
- Python 3.13+
- Dependencies from `pyproject.toml` (pandas, pyarrow or fastparquet).

## Files
- `pipeline.py`: main script that runs the pipeline.
- `main.py`: minimal entry-point example.
- `pyproject.toml`: dependencies and project metadata.
- `Dockerfile`: container build scaffold.

## Usage
1. Install dependencies using your preferred Python environment tool.
2. Run the pipeline with a month number, for example: `python pipeline.py 1`.
3. Check the generated file `output_month_1.parquet` in the working directory.

## Output
The script writes a Parquet file named `output_month_<month>.parquet` containing the sample data.

## Notes
- The pipeline expects a valid integer month argument (e.g., 1–12).
- Parquet writing uses either PyArrow or Fastparquet; ensure one is available.
