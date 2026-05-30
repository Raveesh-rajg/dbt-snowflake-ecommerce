{{
    config(
        materialized='table'
    )
}}

-- =============================================================================
-- dim_dates
-- Calendar dimension spanning Olist's order history.
-- One row per day, with derived attributes for time-series analysis.
-- =============================================================================

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2016-01-01' as date)",
        end_date="cast('2019-12-31' as date)"
    ) }}
),

enriched as (
    select
        date_day                                       as date,
        extract(year     from date_day)                as year,
        extract(quarter  from date_day)                as quarter,
        extract(month    from date_day)                as month,
        to_char(date_day, 'Mon')                       as month_name_short,
        to_char(date_day, 'Month')                     as month_name,
        extract(week     from date_day)                as week_of_year,
        extract(day      from date_day)                as day_of_month,
        extract(dayofweek from date_day)               as day_of_week,
        to_char(date_day, 'Dy')                        as day_name_short,
        to_char(date_day, 'Day')                       as day_name,

        case
            when extract(dayofweek from date_day) in (0, 6) then true
            else false
        end                                            as is_weekend,

        case when date_day = date_trunc('month', date_day) then true else false end as is_month_start,
        case when date_day = last_day(date_day) then true else false end             as is_month_end,
        case when date_day = date_trunc('quarter', date_day) then true else false end as is_quarter_start,
        case when date_day = date_trunc('year', date_day) then true else false end   as is_year_start

    from date_spine
)

select * from enriched