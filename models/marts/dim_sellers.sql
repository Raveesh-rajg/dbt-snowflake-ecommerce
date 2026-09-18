{{ config(materialized='table') }}
select s.*, coalesce(m.orders_fulfilled, 0) as total_orders_fulfilled,
       coalesce(m.items_sold, 0) as total_items_sold, coalesce(m.gross_revenue, 0) as total_revenue,
       round(m.on_time_delivery_pct, 2) as on_time_delivery_pct, m.avg_review as avg_review_score,
       case when m.gross_revenue >= 100000 then 'top_tier'
            when m.gross_revenue >= 10000 then 'mid_tier'
            when m.gross_revenue > 0 then 'low_tier' else 'no_sales' end as seller_tier
from {{ ref('stg_sellers') }} s
left join {{ ref('mart_seller_performance') }} m on s.seller_id = m.seller_id
