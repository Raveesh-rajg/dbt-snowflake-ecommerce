{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'product_category_name_translation') }}
),

renamed as (
    select
        lower(trim(product_category_name))         as product_category_name_pt,
        lower(trim(product_category_name_english)) as product_category_name_en

    from source
)

select * from renamed