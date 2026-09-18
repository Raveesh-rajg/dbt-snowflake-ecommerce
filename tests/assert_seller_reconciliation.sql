select 'seller_revenue' as failure
where abs((select coalesce(sum(gross_revenue_with_freight),0) from {{ ref('mart_seller_performance') }})
 - (select coalesce(sum(total_revenue),0) from {{ ref('fct_orders') }} where is_delivered))>0.01
