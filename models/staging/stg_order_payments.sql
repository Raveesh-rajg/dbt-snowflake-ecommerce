{{ config(materialized='view') }}

with source as (
    select * from {{ source('raw', 'olist_order_payments_dataset') }}
),

renamed as (
    select
        -- FKs and sequence
        order_id,
        payment_sequential,

        -- Payment details
        lower(trim(payment_type)) as payment_type,
        payment_installments,
        payment_value::numeric(10, 2) as payment_value,

        -- Derived: payment categorization
        case
            when lower(trim(payment_type)) = 'credit_card' then true
            else false
        end as is_credit_card,

        case
            when payment_installments > 1 then true
            else false
        end as is_installment_plan

    from source
)

select * from renamed