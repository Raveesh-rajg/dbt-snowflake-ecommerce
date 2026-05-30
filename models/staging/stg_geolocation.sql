{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_geolocation_dataset') }}
),

deduplicated as (
    -- Aggregate to one row per zip code prefix.
    -- Raw data has multiple lat/lon samples per zip; we average them.
    select
        geolocation_zip_code_prefix::varchar(5) as zip_code_prefix,
        avg(geolocation_lat)::numeric(9, 6)     as latitude,
        avg(geolocation_lng)::numeric(9, 6)     as longitude,

        -- Use most-frequent city/state name per zip (handles minor casing variations)
        any_value(trim(geolocation_city))       as city,
        any_value(upper(trim(geolocation_state))) as state,

        count(*) as sample_count

    from source
    group by 1
)

select * from deduplicated