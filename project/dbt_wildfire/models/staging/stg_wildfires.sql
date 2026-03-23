-- Staging model: clean, rename, and type-cast raw wildfire records.
-- One row per fire event. Null discovery dates are excluded.

with source as (
    select *
    from {{ source('wildfire_raw', 'raw_wildfires') }}
    where DISCOVERY_DATE is not null
),

renamed as (
    select
        -- Identifiers
        cast(FOD_ID as int64)               as fire_id,
        FPA_ID                               as fpa_id,
        FIRE_NAME                            as fire_name,
        FIRE_CODE                            as fire_code,

        -- Temporal
        cast(DISCOVERY_DATE as date)         as discovery_date,
        cast(FIRE_YEAR as int64)             as fire_year,
        cast(DISCOVERY_DOY as int64)         as discovery_day_of_year,
        cast(CONT_DATE as date)              as containment_date,

        -- Geography
        STATE                                as state,
        COUNTY                               as county,
        FIPS_CODE                            as fips_code,
        FIPS_NAME                            as fips_name,
        cast(LATITUDE as float64)            as latitude,
        cast(LONGITUDE as float64)           as longitude,

        -- Fire characteristics
        cast(FIRE_SIZE as float64)           as fire_size_acres,
        FIRE_SIZE_CLASS                      as fire_size_class,
        NWCG_CAUSE_CLASSIFICATION            as cause_classification,
        NWCG_GENERAL_CAUSE                   as cause,
        OWNER_DESCR                          as owner_description,

        -- Reporting
        NWCG_REPORTING_AGENCY               as reporting_agency,
        NWCG_REPORTING_UNIT_NAME            as reporting_unit,

        -- Computed
        date_diff(
            cast(CONT_DATE as date),
            cast(DISCOVERY_DATE as date),
            day
        ) as fire_duration_days

    from source
)

select * from renamed
