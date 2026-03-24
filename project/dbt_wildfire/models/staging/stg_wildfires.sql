-- Staging model: clean, rename, and type-cast raw wildfire records.
-- One row per fire event. Null discovery dates are excluded.

with source as (
    select *
    from {{ source('wildfire_raw', 'raw_wildfires') }}
    where disc_clean_date is not null
),

renamed as (
    select
        -- Generate a surrogate key (row number) since this dataset has no unique ID
        row_number() over (order by disc_clean_date, state, fire_name) as fire_id,

        fire_name,

        -- Temporal
        cast(disc_clean_date as date)            as discovery_date,
        cast(disc_pre_year as int64)             as fire_year,
        discovery_month,
        cast(cont_clean_date as date)            as containment_date,
        cast(putout_time as float64)             as putout_time_hours,

        -- Geography
        state,
        cast(latitude as float64)                as latitude,
        cast(longitude as float64)               as longitude,

        -- Fire characteristics
        cast(fire_size as float64)               as fire_size_acres,
        fire_size_class,
        stat_cause_descr                         as cause,
        Vegetation                               as vegetation,
        cast(fire_mag as float64)                as fire_magnitude,
        cast(remoteness as float64)              as remoteness,

        -- Weather conditions (pre-fire and at containment)
        cast(Temp_pre_30 as float64)             as temp_pre_30,
        cast(Temp_pre_15 as float64)             as temp_pre_15,
        cast(Temp_pre_7 as float64)              as temp_pre_7,
        cast(Temp_cont as float64)               as temp_cont,
        cast(Wind_pre_30 as float64)             as wind_pre_30,
        cast(Wind_pre_15 as float64)             as wind_pre_15,
        cast(Wind_pre_7 as float64)              as wind_pre_7,
        cast(Wind_cont as float64)               as wind_cont,
        cast(Hum_pre_30 as float64)              as humidity_pre_30,
        cast(Hum_pre_15 as float64)              as humidity_pre_15,
        cast(Hum_pre_7 as float64)               as humidity_pre_7,
        cast(Hum_cont as float64)                as humidity_cont,
        cast(Prec_pre_30 as float64)             as precip_pre_30,
        cast(Prec_pre_15 as float64)             as precip_pre_15,
        cast(Prec_pre_7 as float64)              as precip_pre_7,
        cast(Prec_cont as float64)               as precip_cont,

        -- Computed
        date_diff(
            cast(cont_clean_date as date),
            cast(disc_clean_date as date),
            day
        ) as fire_duration_days

    from source
)

select * from renamed
