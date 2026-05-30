{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'olist_order_items_dataset') }}
),

renamed as (
    select
        -- Composite key parts
        order_id,
        order_item_id,

        -- FKs
        product_id,
        seller_id,

        -- Dates
        shipping_limit_date::timestamp as shipping_limit_at,

        -- Money
        price::numeric(10, 2)         as item_price,
        freight_value::numeric(10, 2) as freight_value,

        -- Derived
        (price + freight_value)::numeric(10, 2) as total_item_revenue

    from source
)

select * from renamed