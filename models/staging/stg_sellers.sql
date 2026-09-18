{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_sellers_dataset') }}
),

renamed as (
    select
        -- IDs
        seller_id,

        -- Geography
        lpad(cast(seller_zip_code_prefix as varchar), 5, '0') as seller_zip_code_prefix,
        trim(seller_city)                  as seller_city,
        upper(trim(seller_state))          as seller_state

    from source
)

select * from renamed