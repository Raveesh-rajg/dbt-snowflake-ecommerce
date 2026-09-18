{{ config(materialized='table') }}
-- Stable identity grain; locations come from the latest observed order.
with locations as (
    select c.*, row_number() over (
        partition by c.customer_unique_id order by o.ordered_at desc nulls last, c.customer_id desc
    ) as rn
    from {{ ref('stg_customers') }} c
    left join {{ ref('stg_orders') }} o on c.customer_id = o.customer_id
), activity as (
    select customer_unique_id, count(*) as lifetime_order_count,
           sum(total_paid) as lifetime_spend, avg(total_paid) as avg_order_value,
           min(ordered_at) as first_ordered_at, max(ordered_at) as last_ordered_at,
           avg(avg_review_score) as avg_review_score_given
    from {{ ref('fct_orders') }} where is_delivered group by 1
)
select l.customer_unique_id, coalesce(a.lifetime_order_count, 0) as lifetime_order_count,
       coalesce(a.lifetime_spend, 0)::numeric(14,2) as lifetime_spend,
       coalesce(a.avg_order_value, 0)::numeric(14,2) as avg_order_value,
       a.first_ordered_at, a.last_ordered_at,
       datediff('day', a.first_ordered_at, a.last_ordered_at) as customer_tenure_days,
       round(a.avg_review_score_given, 2) as avg_review_score_given,
       l.customer_state as primary_state, l.customer_city as primary_city,
       case when a.lifetime_spend >= 1000 then 'high_value'
            when a.lifetime_spend >= 250 then 'mid_value'
            when a.lifetime_spend > 0 then 'low_value' else 'no_purchase' end as customer_value_tier
from locations l left join activity a on l.customer_unique_id = a.customer_unique_id
where l.rn = 1
