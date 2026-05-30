{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw', 'olist_orders_dataset') }}
),

renamed as (
    select
        -- IDs
        order_id,
        customer_id,

        -- Status
        lower(trim(order_status)) as order_status,

        -- Timestamps (cast string -> timestamp)
        order_purchase_timestamp::timestamp     as ordered_at,
        order_approved_at::timestamp            as approved_at,
        order_delivered_carrier_date::timestamp as shipped_at,
        order_delivered_customer_date::timestamp as delivered_at,
        order_estimated_delivery_date::timestamp as estimated_delivery_at,

        -- Derived: was this order delivered late?
        case
            when order_delivered_customer_date is null then null
            when order_delivered_customer_date::timestamp > order_estimated_delivery_date::timestamp then true
            else false
        end as was_delivered_late

    from source
)

select * from renamed
