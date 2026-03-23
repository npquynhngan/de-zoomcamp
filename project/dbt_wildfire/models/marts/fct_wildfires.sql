-- Fact table: one row per fire event, enriched with date parts.
-- Partitioned by discovery_date, clustered by state and cause.
-- {{ config(...) }} sets BigQuery-specific options.

{{
    config(
        materialized='table',
        partition_by={
            "field": "discovery_date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by=["state", "cause"],
    )
}}

with base as (
    select * from {{ ref('stg_wildfires') }}
)

select
    fire_id,
    fpa_id,
    fire_name,

    -- Date dimensions
    discovery_date,
    fire_year,
    extract(month from discovery_date)          as discovery_month,
    extract(quarter from discovery_date)        as discovery_quarter,
    format_date('%B', discovery_date)           as discovery_month_name,
    extract(dayofweek from discovery_date)      as discovery_day_of_week,
    containment_date,
    fire_duration_days,

    -- Geography
    state,
    county,
    fips_code,
    fips_name,
    latitude,
    longitude,

    -- Fire characteristics
    fire_size_acres,
    fire_size_class,
    {{ size_class_label('fire_size_class') }}   as fire_size_label,
    cause_classification,
    cause,
    owner_description,
    reporting_agency

from base
