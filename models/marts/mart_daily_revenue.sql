{{ config(materialized='table') }}
-- Full refresh is intentional: a small daily table must reflect historical corrections.
-- All statuses count as orders; revenue/items/customer metrics count delivered orders.
with daily as (
    select cast(ordered_at as date) as order_date, count(*) as orders_count,
           count(distinct case when is_delivered then customer_unique_id end) as unique_customers,
           sum(case when is_delivered then 1 else 0 end) as delivered_orders,
           sum(case when is_delivered then total_revenue else 0 end) as daily_revenue,
           sum(case when is_delivered then total_items else 0 end) as items_sold,
           sum(case when is_delivered and was_delivered_late then 1 else 0 end) as late_orders,
           sum(case when is_delivered and was_delivered_late is not null then 1 else 0 end) as delivery_observed_orders,
           avg(case when is_delivered then avg_review_score end) as daily_avg_review
    from {{ ref('fct_orders') }} group by 1
), dense as (
    select d.date as order_date, coalesce(o.orders_count, 0) as orders_count,
           coalesce(o.unique_customers, 0) as unique_customers,
           coalesce(o.delivered_orders, 0) as delivered_orders,
           coalesce(o.daily_revenue, 0)::numeric(14,2) as daily_revenue,
           coalesce(o.items_sold, 0) as items_sold, coalesce(o.late_orders, 0) as late_orders,
           coalesce(o.delivery_observed_orders, 0) as delivery_observed_orders,
           round(o.daily_avg_review, 2) as daily_avg_review
    from {{ ref('dim_dates') }} d left join daily o on d.date = o.order_date
)
select *,
       avg(daily_revenue) over (order by order_date rows between 6 preceding and current row)::numeric(14,2) as revenue_7day_avg,
       avg(daily_revenue) over (order by order_date rows between 29 preceding and current row)::numeric(14,2) as revenue_30day_avg,
       sum(daily_revenue) over (order by order_date rows between 6 preceding and current row)::numeric(14,2) as revenue_7day_sum,
       round(100.0 * (daily_revenue - lag(daily_revenue) over (order by order_date)) /
             nullif(lag(daily_revenue) over (order by order_date), 0), 2) as revenue_dod_pct_change
from dense
