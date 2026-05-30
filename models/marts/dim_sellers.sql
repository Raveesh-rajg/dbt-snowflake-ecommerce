{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- dim_sellers
-- One row per seller_id, enriched with fulfillment performance and review scores.
-- =============================================================================

with sellers as (
    select * from {{ ref('stg_sellers') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

-- Aggregate fulfillment performance per seller
seller_performance as (
    select
        oi.seller_id,
        count(distinct oi.order_id)                    as total_orders_fulfilled,
        count(*)                                       as total_items_sold,
        sum(oi.item_price)::numeric(12, 2)             as total_revenue,
        sum(oi.total_item_revenue)::numeric(12, 2)     as total_revenue_with_freight,

        -- On-time delivery rate, computed at the DISTINCT ORDER level
        -- (count distinct orders that weren't late / count distinct orders)
        count(distinct case when o.was_delivered_late = false then o.order_id end)::float
            / nullif(count(distinct o.order_id), 0)
            as on_time_delivery_rate,

        avg(r.review_score)::numeric(3, 2)             as avg_review_score

    from order_items oi
    join orders   o on oi.order_id = o.order_id
    left join reviews r on o.order_id = r.order_id
    group by oi.seller_id
)

select
    s.seller_id,

    -- Geography
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    -- Performance metrics
    coalesce(sp.total_orders_fulfilled, 0)          as total_orders_fulfilled,
    coalesce(sp.total_items_sold, 0)                as total_items_sold,
    coalesce(sp.total_revenue, 0)::numeric(12, 2)   as total_revenue,
    round(sp.on_time_delivery_rate * 100, 2)        as on_time_delivery_pct,
    round(sp.avg_review_score, 2)                   as avg_review_score,

    -- Seller tier
    case
        when sp.total_revenue >= 100000 then 'top_tier'
        when sp.total_revenue >= 10000  then 'mid_tier'
        when sp.total_revenue >  0      then 'low_tier'
        else 'no_sales'
    end as seller_tier

from sellers s
left join seller_performance sp on s.seller_id = sp.seller_id
