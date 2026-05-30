{#
    cents_to_brl
    ---------------------------------------------------------------------------
    Formats a numeric column as Brazilian Real currency string.
    Example: cents_to_brl('payment_value') compiles to:
        'R$ ' || to_char(payment_value, 'FM999G999G990D00')

    Args:
        column_name (string): The column or expression to format.

    Returns:
        A string expression with 'R$' prefix and BR-formatted number.
#}
{% macro cents_to_brl(column_name) %}
    'R$ ' || to_char({{ column_name }}, 'FM999G999G990D00')
{% endmacro %}