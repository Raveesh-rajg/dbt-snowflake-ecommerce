select d.date from {{ ref('dim_dates') }} d
left join {{ ref('mart_daily_revenue') }} m on d.date=m.order_date where m.order_date is null
