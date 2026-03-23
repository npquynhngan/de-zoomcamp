-- State × cause aggregated statistics — used for the categorical dashboard tile.

{{
    config(materialized='table')
}}

with fires as (
    select * from {{ ref('stg_wildfires') }}
)

select
    state,
    cause,
    cause_classification,

    count(*)                                as fire_count,
    round(sum(fire_size_acres), 2)          as total_acres_burned,
    round(avg(fire_size_acres), 2)          as avg_fire_size_acres,
    round(avg(fire_duration_days), 1)       as avg_duration_days,

    -- Fire size class breakdown
    countif(fire_size_class = 'A')          as class_a_count,
    countif(fire_size_class = 'B')          as class_b_count,
    countif(fire_size_class = 'C')          as class_c_count,
    countif(fire_size_class in ('D','E','F','G')) as class_large_count

from fires
group by 1, 2, 3
order by fire_count desc
