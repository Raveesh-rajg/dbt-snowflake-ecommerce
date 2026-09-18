with expected as (
select coalesce(sum(i.price + i.freight_value),0) as revenue
from {{ source('raw','olist_order_items_dataset') }} i
join {{ source('raw','olist_orders_dataset') }} o on i.order_id=o.order_id
where lower(trim(o.order_status))='delivered'
), actual as (
select coalesce(sum(daily_revenue),0) as revenue from {{ ref('mart_daily_revenue') }}
)
select expected.revenue, actual.revenue from expected cross join actual
where abs(expected.revenue-actual.revenue)>0.01
