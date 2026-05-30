{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'olist_customers_dataset') }}
),

renamed as (
    select
        -- IDs
        customer_id,
        customer_unique_id,

        -- Geography
        customer_zip_code_prefix::varchar(5) as customer_zip_code_prefix,
        trim(customer_city)                  as customer_city,
        upper(trim(customer_state))          as customer_state

    from source
)

select * from renamed