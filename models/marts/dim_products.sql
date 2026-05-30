{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- dim_products
-- One row per product_id, enriched with sales performance and bilingual category.
-- LEFT JOIN to translation handles missing translations (data quality finding).
-- =============================================================================

with products as (
    select * from {{ ref('stg_products') }}
),

translations as (
    select * from {{ ref('stg_product_category_translation') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- Aggregate sales performance per product
product_sales as (
    select
        oi.product_id,
        count(*) as units_sold,
        sum(oi.item_price)         as total_revenue,
        sum(oi.total_item_revenue) as total_revenue_with_freight,
        avg(oi.item_price)         as avg_selling_price
    from order_items oi
    group by oi.product_id
),

-- Aggregate review scores per product (via order_items -> orders -> reviews)
product_reviews as (
    select
        oi.product_id,
        avg(r.review_score) as avg_review_score
    from order_items oi
    join orders  o on oi.order_id = o.order_id
    join reviews r on o.order_id  = r.order_id
    group by oi.product_id
)

select
    p.product_id,

    -- Category (bilingual, with fallback for missing translations)
    p.product_category_name_pt,
    coalesce(t.product_category_name_en, p.product_category_name_pt) as product_category_name_en,

    -- Content metrics
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,

    -- Physical attributes
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volume_cm3,

    -- Sales performance
    coalesce(ps.units_sold, 0)                              as units_sold,
    coalesce(ps.total_revenue, 0)::numeric(12, 2)           as total_revenue,
    coalesce(ps.avg_selling_price, 0)::numeric(10, 2)       as avg_selling_price,
    round(pr.avg_review_score, 2)                           as avg_review_score,

    -- Performance tier
    case
        when ps.units_sold >= 100 then 'bestseller'
        when ps.units_sold >= 20  then 'mid_volume'
        when ps.units_sold >  0   then 'low_volume'
        else 'never_sold'
    end as product_performance_tier

from products p
left join translations   t  on p.product_category_name_pt = t.product_category_name_pt
left join product_sales  ps on p.product_id               = ps.product_id
left join product_reviews pr on p.product_id              = pr.product_id