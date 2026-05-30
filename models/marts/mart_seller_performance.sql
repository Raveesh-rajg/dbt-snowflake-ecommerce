{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- mart_seller_performance
-- One row per seller with operational & financial KPIs + rankings.
-- Different from dim_sellers: this is analysis-ready with percentile segments.
-- =============================================================================

with seller_metrics as (
    select
        oi.seller_id,
        s.seller_state,

        -- Volume
        count(distinct o.order_id)                       as orders_fulfilled,
        count(*)                                         as items_sold,
        count(distinct date(o.ordered_at))               as active_days,

        -- Revenue
        sum(oi.item_price)::numeric(14, 2)               as gross_revenue,
        sum(oi.total_item_revenue)::numeric(14, 2)       as gross_revenue_with_freight,
        avg(oi.item_price)::numeric(10, 2)               as avg_item_price,

        -- Quality / customer experience
        count(distinct case when o.was_delivered_late = false then o.order_id end)::float
            / nullif(count(distinct o.order_id), 0)        as on_time_rate,
        avg(o.avg_review_score)::numeric(3, 2)           as avg_review,
        sum(case when o.has_negative_review then 1 else 0 end) as negative_review_count,

        -- Activity window
        min(o.ordered_at)                                as first_sale_at,
        max(o.ordered_at)                                as last_sale_at

    from {{ ref('stg_order_items') }} oi
    join {{ ref('fct_orders') }} o on oi.order_id = o.order_id
    join {{ ref('stg_sellers') }} s on oi.seller_id = s.seller_id
    group by oi.seller_id, s.seller_state
),

with_rankings as (
    select
        *,

        -- Revenue ranking
        rank() over (order by gross_revenue desc) as revenue_rank,
        ntile(10) over (order by gross_revenue desc) as revenue_decile,

        -- Quality ranking (separate from revenue — different signal)
        rank() over (
            order by avg_review desc nulls last, on_time_rate desc nulls last
        ) as quality_rank,

        -- Rank within state
        rank() over (
            partition by seller_state
            order by gross_revenue desc
        ) as state_revenue_rank

    from seller_metrics
)

select
    seller_id,
    seller_state,
    orders_fulfilled,
    items_sold,
    active_days,
    gross_revenue,
    gross_revenue_with_freight,
    avg_item_price,
    round(on_time_rate * 100, 2) as on_time_delivery_pct,
    avg_review,
    negative_review_count,
    first_sale_at,
    last_sale_at,

    -- Rankings
    revenue_rank,
    revenue_decile,
    quality_rank,
    state_revenue_rank,

    -- Combined performance segment
    case
        when revenue_decile = 1 and avg_review >= 4.0 then 'star_performer'
        when revenue_decile = 1 and avg_review <  4.0 then 'high_volume_quality_risk'
        when revenue_decile <= 3 and avg_review >= 4.0 then 'rising_performer'
        when avg_review < 3.0 then 'quality_concern'
        else 'standard'
    end as performance_segment

from with_rankings