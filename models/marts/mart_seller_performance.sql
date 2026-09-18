{{ config(materialized='table') }}
-- Aggregate items BEFORE computing order-level reviews and delivery rates.
with seller_orders as (
    select seller_id, order_id, count(*) as items_sold, sum(item_price) as gross_revenue,
           sum(total_item_revenue) as gross_revenue_with_freight
    from {{ ref('stg_order_items') }} group by 1, 2
), metrics as (
    select so.seller_id, s.seller_state, count(*) as orders_fulfilled,
           sum(so.items_sold) as items_sold, count(distinct cast(o.ordered_at as date)) as active_days,
           sum(so.gross_revenue)::numeric(14,2) as gross_revenue,
           sum(so.gross_revenue_with_freight)::numeric(14,2) as gross_revenue_with_freight,
           (sum(so.gross_revenue) / nullif(sum(so.items_sold), 0))::numeric(14,2) as avg_item_price,
           100.0 * sum(case when o.was_delivered_late = false then 1 else 0 end) /
               nullif(sum(case when o.was_delivered_late is not null then 1 else 0 end), 0) as on_time_delivery_pct,
           round(avg(o.avg_review_score), 2) as avg_review,
           sum(case when o.has_negative_review then 1 else 0 end) as negative_review_count,
           min(o.ordered_at) as first_sale_at, max(o.ordered_at) as last_sale_at
    from seller_orders so join {{ ref('fct_orders') }} o on so.order_id = o.order_id
    join {{ ref('stg_sellers') }} s on so.seller_id = s.seller_id
    where o.is_delivered group by 1, 2
), ranked as (
    select *, rank() over (order by gross_revenue desc) as revenue_rank,
           ntile(10) over (order by gross_revenue desc, seller_id) as revenue_decile,
           rank() over (order by avg_review desc nulls last, on_time_delivery_pct desc nulls last) as quality_rank,
           rank() over (partition by seller_state order by gross_revenue desc) as state_revenue_rank
    from metrics
)
select *, case when revenue_decile = 1 and avg_review >= 4 then 'star_performer'
               when revenue_decile = 1 and avg_review < 4 then 'high_volume_quality_risk'
               when revenue_decile <= 3 and avg_review >= 4 then 'rising_performer'
               when avg_review < 3 then 'quality_concern' else 'standard' end as performance_segment
from ranked
