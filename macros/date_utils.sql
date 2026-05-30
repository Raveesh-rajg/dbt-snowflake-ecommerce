{#
    days_between_safe
    ---------------------------------------------------------------------------
    Returns the day count between two dates/timestamps, NULL-safe.
    Returns NULL if either input is NULL.
    Returns NULL if start_date > end_date (avoids negative-days noise).

    Args:
        start_date (column): The earlier date.
        end_date (column): The later date.

    Returns:
        Integer day count, or NULL.
#}
{% macro days_between_safe(start_date, end_date) %}
    case
        when {{ start_date }} is null or {{ end_date }} is null then null
        when {{ start_date }} > {{ end_date }} then null
        else datediff('day', {{ start_date }}, {{ end_date }})
    end
{% endmacro %}