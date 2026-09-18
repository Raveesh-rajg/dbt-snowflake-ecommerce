{% macro iso_weekday(column) %}
  {% if target.type == 'snowflake' %} dayofweekiso({{ column }})
  {% else %} extract(isodow from {{ column }}) {% endif %}
{% endmacro %}
