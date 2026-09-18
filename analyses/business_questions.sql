-- Delivered order value by month. BRL, including freight; not net revenue.
select date_trunc('month', order_date) as month,
       sum(daily_revenue) as delivered_order_value_brl,
       sum(delivered_orders) as delivered_orders,
       sum(daily_revenue) / nullif(sum(delivered_orders), 0) as delivered_aov_brl
from {{ ref('mart_daily_revenue') }} group by 1 order by 1;

-- Customer concentration. Rank buckets are by lifetime value; not causal segments.
select customer_segment, count(*) as customers,
       sum(lifetime_revenue) as lifetime_order_value_brl
from {{ ref('mart_customer_lifetime_value') }} group by 1;

-- High-value sellers with low reviews deserve investigation, not automatic sanction.
select seller_id, gross_revenue, avg_review, on_time_delivery_pct, orders_fulfilled
from {{ ref('mart_seller_performance') }}
where avg_review < 4 order by gross_revenue desc;
