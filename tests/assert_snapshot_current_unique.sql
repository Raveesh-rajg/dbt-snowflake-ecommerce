select order_id from {{ ref('snap_orders_status') }} where dbt_valid_to is null
group by order_id having count(*) > 1
