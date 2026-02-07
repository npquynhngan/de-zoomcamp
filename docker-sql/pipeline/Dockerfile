FROM python:3.13.11-slim

# Copy uv binary from official uv image (multi-stage build pattern)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

WORKDIR /code

#Add virtual environment path to PATH so we can use installed packages
ENV PATH="/code/.venv/bin:$PATH"

COPY pyproject.toml .python-version uv.lock ./
RUN uv sync --locked

COPY pipeline.py .
ENTRYPOINT ["python", "pipeline.py"]