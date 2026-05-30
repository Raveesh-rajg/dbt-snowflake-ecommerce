{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- mart_customer_lifetime_value
-- One row per customer_unique_id with CLV metrics and ranking-based segments.
-- Showcases: RANK(), NTILE(), PERCENT_RANK() window functions.
-- =============================================================================

with customer_orders as (
    -- Aggregate at customer_unique_id grain (the stable identity)
    select
        c.customer_unique_id,
        c.customer_state,
        count(distinct o.order_id)                       as lifetime_orders,
        sum(o.total_revenue)::numeric(14, 2)             as lifetime_revenue,
        avg(o.total_revenue)::numeric(10, 2)             as avg_order_value,
        min(o.ordered_at)                                as first_order_at,
        max(o.ordered_at)                                as last_order_at,
        datediff('day', min(o.ordered_at), max(o.ordered_at)) as customer_tenure_days,
        avg(o.avg_review_score)::numeric(3, 2)           as avg_review_given,
        sum(case when o.was_delivered_late then 1 else 0 end) as late_orders_received
    from {{ ref('fct_orders') }} o
    join {{ ref('stg_customers') }} c on o.customer_id = c.customer_id
    where o.total_revenue > 0
    group by c.customer_unique_id, c.customer_state
),

with_rankings as (
    select
        *,

        -- Pure ordinal rank (1 = highest spender)
        rank() over (order by lifetime_revenue desc) as revenue_rank,

        -- Decile bucket: 1 = top 10%, 10 = bottom 10%
        ntile(10) over (order by lifetime_revenue desc) as revenue_decile,

        -- Quartile bucket
        ntile(4) over (order by lifetime_revenue desc) as revenue_quartile,

        -- Percentile (0.0 to 1.0)
        round(
            (1 - percent_rank() over (order by lifetime_revenue))::numeric, 4
        ) as revenue_percentile,

        -- Rank within state (for "top customer in São Paulo" style queries)
        rank() over (
            partition by customer_state
            order by lifetime_revenue desc
        ) as state_revenue_rank

    from customer_orders
)

select
    customer_unique_id,
    customer_state,
    lifetime_orders,
    lifetime_revenue,
    avg_order_value,
    first_order_at,
    last_order_at,
    customer_tenure_days,
    avg_review_given,
    late_orders_received,

    -- Rankings
    revenue_rank,
    revenue_decile,
    revenue_quartile,
    revenue_percentile,
    state_revenue_rank,

    -- Named segment for BI tools
    case
        when revenue_decile = 1  then 'top_10_pct'
        when revenue_decile <= 3 then 'top_30_pct'
        when revenue_decile <= 5 then 'top_50_pct'
        else 'bottom_50_pct'
    end as customer_segment

from with_rankings