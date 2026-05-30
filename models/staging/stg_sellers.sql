{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_sellers_dataset') }}
),

renamed as (
    select
        -- IDs
        seller_id,

        -- Geography
        seller_zip_code_prefix::varchar(5) as seller_zip_code_prefix,
        trim(seller_city)                  as seller_city,
        upper(trim(seller_state))          as seller_state

    from source
)

select * from renamed