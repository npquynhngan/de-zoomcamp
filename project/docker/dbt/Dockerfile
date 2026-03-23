FROM ghcr.io/dbt-labs/dbt-bigquery:1.8.0

WORKDIR /dbt

# dbt_wildfire project files are mounted at runtime via docker compose volume
# This Dockerfile just ensures the correct dbt-bigquery image is used

ENTRYPOINT ["dbt"]
CMD ["run", "--profiles-dir", "/dbt", "--project-dir", "/dbt"]
