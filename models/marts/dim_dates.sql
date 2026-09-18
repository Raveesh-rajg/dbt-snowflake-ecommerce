{{ config(materialized='table') }}
-- The calendar includes zero-order days and exactly covers observed purchases.
with recursive bounds as (
    select cast(min(ordered_at) as date) as first_date, cast(max(ordered_at) as date) as last_date
    from {{ ref('stg_orders') }}
), calendar(date_day) as (
    select first_date from bounds where first_date is not null
    union all
    select cast({{ dbt.dateadd('day', 1, 'date_day') }} as date)
    from calendar cross join bounds where date_day < last_date
)
select date_day as date, extract(year from date_day) as year,
       extract(quarter from date_day) as quarter, extract(month from date_day) as month,
       extract(day from date_day) as day_of_month,
       {{ iso_weekday('date_day') }} as day_of_week,
       {{ iso_weekday('date_day') }} in (6, 7) as is_weekend,
       date_day = cast(date_trunc('month', date_day) as date) as is_month_start,
       date_day = last_day(date_day) as is_month_end,
       date_day = cast(date_trunc('quarter', date_day) as date) as is_quarter_start,
       date_day = cast(date_trunc('year', date_day) as date) as is_year_start
from calendar
