select 'order_count' as failure
where (select count(*) from {{ ref('fct_orders') }}) != (select count(*) from {{ ref('stg_orders') }})
