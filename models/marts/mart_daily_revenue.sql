{{
    config(
        materialized='incremental',
        unique_key='order_date',
        on_schema_change='fail'
    )
}}

-- =============================================================================
-- mart_daily_revenue
-- One row per day with revenue metrics + 7-day & 30-day rolling averages.
-- INCREMENTAL: on subsequent runs, only re-processes the last 7 days
--   (rolling windows need recent history to recompute correctly).
-- =============================================================================

with daily_orders as (
    select
        date(ordered_at)               as order_date,
        count(*)                       as orders_count,
        count(distinct customer_id)    as unique_customers,
        sum(total_revenue)::numeric(14, 2)  as daily_revenue,
        sum(total_items)               as items_sold,
        sum(case when was_delivered_late then 1 else 0 end) as late_orders,
        avg(avg_review_score)::numeric(3, 2) as daily_avg_review
    from {{ ref('fct_orders') }}
    where ordered_at is not null

    {% if is_incremental() %}
        -- On incremental runs: only re-process the trailing window
        -- (need 30 days history to recompute the 30-day rolling correctly)
        and date(ordered_at) >= (select dateadd('day', -30, max(order_date)) from {{ this }})
    {% endif %}

    group by 1
),

with_rolling as (
    select
        order_date,
        orders_count,
        unique_customers,
        daily_revenue,
        items_sold,
        late_orders,
        daily_avg_review,

        -- 7-day rolling average revenue
        avg(daily_revenue) over (
            order by order_date
            rows between 6 preceding and current row
        )::numeric(14, 2) as revenue_7day_avg,

        -- 30-day rolling average revenue
        avg(daily_revenue) over (
            order by order_date
            rows between 29 preceding and current row
        )::numeric(14, 2) as revenue_30day_avg,

        -- 7-day rolling sum (week-to-date style)
        sum(daily_revenue) over (
            order by order_date
            rows between 6 preceding and current row
        )::numeric(14, 2) as revenue_7day_sum,

        -- Day-over-day change %
        case
            when lag(daily_revenue) over (order by order_date) is null
                 or lag(daily_revenue) over (order by order_date) = 0 then null
            else round(
                100.0 * (daily_revenue - lag(daily_revenue) over (order by order_date))
                / lag(daily_revenue) over (order by order_date),
                2
            )
        end as revenue_dod_pct_change

    from daily_orders
)

select * from with_rolling