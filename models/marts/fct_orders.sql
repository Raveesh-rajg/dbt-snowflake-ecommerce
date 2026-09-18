{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- fct_orders
-- One row per order, enriched with customer info, item totals, payment totals,
-- review score, delivery duration, and derived business flags.
-- Joins: stg_orders + stg_customers + stg_order_items + stg_order_payments + stg_order_reviews
-- =============================================================================

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

order_items_agg as (
    -- Aggregate to one row per order
    select
        order_id,
        count(*)                                  as total_items,
        count(distinct product_id)                as distinct_products,
        count(distinct seller_id)                 as distinct_sellers,
        sum(item_price)::numeric(12, 2)           as items_subtotal,
        sum(freight_value)::numeric(12, 2)        as total_freight,
        sum(total_item_revenue)::numeric(12, 2)   as total_revenue
    from {{ ref('stg_order_items') }}
    group by order_id
),

payments_agg as (
    -- Aggregate to one row per order
    select
        order_id,
        count(*)                              as payment_count,
        sum(payment_value)::numeric(12, 2)    as total_paid,
        max(payment_installments)             as max_installments,
        -- Count/value ranking below supplies the modal payment type.
        count(distinct payment_type)          as payment_types_count
    from {{ ref('stg_order_payments') }}
    group by order_id
),

payment_type_counts as (
    select order_id, payment_type, count(*) as occurrences, sum(payment_value) as type_value
    from {{ ref('stg_order_payments') }} group by order_id, payment_type
), payment_type_ranked as (
    select *, row_number() over (
        partition by order_id order by occurrences desc, type_value desc, payment_type
    ) as rn from payment_type_counts
),
reviews_agg as (
    -- Some orders have multiple reviews (data quality finding); take avg
    select
        order_id,
        avg(review_score)::numeric(3, 2)      as avg_review_score,
        max(case when is_positive_review then 1 else 0 end)::boolean as has_positive_review,
        max(case when is_negative_review then 1 else 0 end)::boolean as has_negative_review
    from {{ ref('stg_order_reviews') }}
    group by order_id
)

select
    -- Order keys
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,

    -- Order lifecycle
    o.order_status,
    o.ordered_at,
    o.approved_at,
    o.shipped_at,
    o.delivered_at,
    o.estimated_delivery_at,

    -- Order composition
    coalesce(oi.total_items, 0)         as total_items,
    coalesce(oi.distinct_products, 0)   as distinct_products,
    coalesce(oi.distinct_sellers, 0)    as distinct_sellers,

    -- Revenue (from order_items)
    coalesce(oi.items_subtotal, 0)::numeric(12, 2)  as items_subtotal,
    coalesce(oi.total_freight, 0)::numeric(12, 2)   as total_freight,
    coalesce(oi.total_revenue, 0)::numeric(12, 2)   as total_revenue,

    -- Payment
    coalesce(p.total_paid, 0)::numeric(12, 2)   as total_paid,
    p.payment_count,
    p.max_installments,
    pt.payment_type as primary_payment_type,

    -- Reviews
    r.avg_review_score,
    coalesce(r.has_positive_review, false) as has_positive_review,
    coalesce(r.has_negative_review, false) as has_negative_review,

    -- Delivery metrics
    o.was_delivered_late,
    {{ days_between_safe('o.ordered_at', 'o.delivered_at') }} as delivery_duration_days,
    datediff('day', o.estimated_delivery_at, o.delivered_at) as days_vs_estimate,

    -- Derived flags
    case when o.order_status = 'delivered' then true else false end as is_delivered,
    case when o.order_status = 'canceled'  then true else false end as is_canceled

from orders o
left join customers       c   on o.customer_id = c.customer_id
left join order_items_agg oi  on o.order_id    = oi.order_id
left join payments_agg    p   on o.order_id    = p.order_id
left join payment_type_ranked pt on o.order_id = pt.order_id and pt.rn = 1
left join reviews_agg     r   on o.order_id    = r.order_id