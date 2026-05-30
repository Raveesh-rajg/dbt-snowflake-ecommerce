{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_products_dataset') }}
),

renamed as (
    select
        -- IDs
        product_id,

        -- Category
        lower(trim(product_category_name)) as product_category_name_pt,

        -- Content metrics (Olist's source typo "lenght" corrected to "length")
        product_name_lenght::integer        as product_name_length,
        product_description_lenght::integer as product_description_length,
        product_photos_qty::integer         as product_photos_qty,

        -- Physical dimensions
        product_weight_g::numeric(10, 2) as product_weight_g,
        product_length_cm::numeric(10, 2) as product_length_cm,
        product_height_cm::numeric(10, 2) as product_height_cm,
        product_width_cm::numeric(10, 2)  as product_width_cm,

        -- Derived: package volume in cm^3 (useful for shipping cost analysis)
        (product_length_cm * product_height_cm * product_width_cm)::numeric(12, 2)
            as product_volume_cm3

    from source
)

select * from renamed