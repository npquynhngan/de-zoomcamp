-- Monthly aggregated fire statistics — used for the temporal dashboard tile.

{{
    config(materialized='table')
}}

with fires as (
    select * from {{ ref('stg_wildfires') }}
)

select
    fire_year,
    extract(month from discovery_date)      as fire_month,
    date_trunc(discovery_date, month)        as year_month,
    state,

    count(*)                                as fire_count,
    round(sum(fire_size_acres), 2)          as total_acres_burned,
    round(avg(fire_size_acres), 2)          as avg_fire_size_acres,
    round(max(fire_size_acres), 2)          as max_fire_size_acres,
    round(avg(fire_duration_days), 1)       as avg_duration_days

from fires
group by 1, 2, 3, 4
order by 1, 2, 4
