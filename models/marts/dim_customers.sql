{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- dim_customers
-- One row per customer_unique_id (the stable customer identity across orders).
-- Enriched with: order count, total spend, first/last order, avg review given.
-- =============================================================================

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

payments as (
    select * from {{ ref('stg_order_payments') }}
),

reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

-- Aggregate payment value per order (orders can have multiple payment rows)
order_totals as (
    select
        order_id,
        sum(payment_value) as order_total
    from payments
    group by order_id
),

-- Aggregate one row per customer_unique_id
customer_aggregates as (
    select
        c.customer_unique_id,

        -- Order activity
        count(distinct o.order_id) as lifetime_order_count,

        -- Spend
        sum(ot.order_total)        as lifetime_spend,
        avg(ot.order_total)        as avg_order_value,

        -- Time window
        min(o.ordered_at)          as first_ordered_at,
        max(o.ordered_at)          as last_ordered_at,

        -- Review behavior (avg score this customer GAVE)
        avg(r.review_score)        as avg_review_score_given,

        -- Primary location (most recent state observed)
        max(c.customer_state)      as primary_state,
        max(c.customer_city)       as primary_city

    from customers c
    left join orders       o  on c.customer_id = o.customer_id
    left join order_totals ot on o.order_id   = ot.order_id
    left join reviews      r  on o.order_id   = r.order_id
    group by c.customer_unique_id
)

select
    customer_unique_id,
    lifetime_order_count,
    coalesce(lifetime_spend, 0)::numeric(12, 2)    as lifetime_spend,
    coalesce(avg_order_value, 0)::numeric(10, 2)   as avg_order_value,
    first_ordered_at,
    last_ordered_at,
    datediff('day', first_ordered_at, last_ordered_at) as customer_tenure_days,
    round(avg_review_score_given, 2)               as avg_review_score_given,
    primary_state,
    primary_city,

    -- Customer segmentation tier (simple, business-readable)
    case
        when lifetime_spend >= 1000 then 'high_value'
        when lifetime_spend >= 250  then 'mid_value'
        when lifetime_spend > 0     then 'low_value'
        else 'no_purchase'
    end as customer_value_tier

from customer_aggregates