select 'customer_revenue' as failure
where abs((select coalesce(sum(lifetime_revenue),0) from {{ ref('mart_customer_lifetime_value') }})
 - (select coalesce(sum(total_revenue),0) from {{ ref('fct_orders') }} where is_delivered))>0.01
