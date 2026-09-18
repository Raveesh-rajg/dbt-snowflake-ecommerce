{{ config(materialized='view') }}
-- One row per prefix. Deterministic modal city/state pair; average coordinates.
with locations as (
    select lpad(cast(geolocation_zip_code_prefix as varchar), 5, '0') as zip_code_prefix,
           trim(geolocation_city) as city, upper(trim(geolocation_state)) as state,
           geolocation_lat, geolocation_lng
    from {{ source('raw', 'olist_geolocation_dataset') }}
), ranked as (
    select zip_code_prefix, city, state,
           row_number() over (partition by zip_code_prefix order by count(*) desc, city, state) as rn
    from locations group by 1, 2, 3
), coordinates as (
    select zip_code_prefix, avg(geolocation_lat)::numeric(9,6) as latitude,
           avg(geolocation_lng)::numeric(9,6) as longitude, count(*) as sample_count
    from locations group by 1
)
select c.*, r.city, r.state from coordinates c
join ranked r on c.zip_code_prefix = r.zip_code_prefix and r.rn = 1
