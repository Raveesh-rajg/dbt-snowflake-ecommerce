"""Olist CSV contract shared by the demo, local loader and Snowflake loader."""
SCHEMAS = {
    'olist_customers_dataset': dict.fromkeys(['customer_id','customer_unique_id','customer_zip_code_prefix','customer_city','customer_state'], 'VARCHAR'),
    'olist_orders_dataset': dict.fromkeys(['order_id','customer_id','order_status','order_purchase_timestamp','order_approved_at','order_delivered_carrier_date','order_delivered_customer_date','order_estimated_delivery_date'], 'VARCHAR'),
    'olist_order_items_dataset': {'order_id':'VARCHAR','order_item_id':'INTEGER','product_id':'VARCHAR','seller_id':'VARCHAR','shipping_limit_date':'VARCHAR','price':'DECIMAL(14,2)','freight_value':'DECIMAL(14,2)'},
    'olist_order_payments_dataset': {'order_id':'VARCHAR','payment_sequential':'INTEGER','payment_type':'VARCHAR','payment_installments':'INTEGER','payment_value':'DECIMAL(14,2)'},
    'olist_order_reviews_dataset': {'review_id':'VARCHAR','order_id':'VARCHAR','review_score':'INTEGER','review_comment_title':'VARCHAR','review_comment_message':'VARCHAR','review_creation_date':'VARCHAR','review_answer_timestamp':'VARCHAR'},
    'olist_products_dataset': {'product_id':'VARCHAR','product_category_name':'VARCHAR', **dict.fromkeys(['product_name_lenght','product_description_lenght','product_photos_qty','product_weight_g','product_length_cm','product_height_cm','product_width_cm'], 'INTEGER')},
    'olist_sellers_dataset': dict.fromkeys(['seller_id','seller_zip_code_prefix','seller_city','seller_state'], 'VARCHAR'),
    'olist_geolocation_dataset': {'geolocation_zip_code_prefix':'VARCHAR','geolocation_lat':'DOUBLE','geolocation_lng':'DOUBLE','geolocation_city':'VARCHAR','geolocation_state':'VARCHAR'},
    'product_category_name_translation': {'product_category_name':'VARCHAR','product_category_name_english':'VARCHAR'},
}

def validate_files(directory):
    import csv
    from pathlib import Path
    paths = []
    for table, columns in SCHEMAS.items():
        path = Path(directory) / f'{table}.csv'
        with path.open(encoding='utf-8-sig', newline='') as f:
            header = next(csv.reader(f))
        if header != list(columns):
            raise ValueError(f'{path.name}: expected columns {list(columns)}, got {header}')
        paths.append(path)
    return paths
