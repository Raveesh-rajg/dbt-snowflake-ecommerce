select order_id from {{ ref('fct_orders') }}
where total_revenue < 0 or total_paid < 0 or items_subtotal < 0 or total_freight < 0
or abs(total_revenue-items_subtotal-total_freight)>0.01
union all
select seller_id from {{ ref('mart_seller_performance') }}
where on_time_delivery_pct < 0 or on_time_delivery_pct > 100 or avg_review < 1 or avg_review > 5
