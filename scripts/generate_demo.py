"""Deterministic, explicitly synthetic Olist-shaped regression data. No downloads."""
import argparse
import csv
from datetime import datetime, timedelta
from pathlib import Path
from data_contract import SCHEMAS

def generate(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    data = {name: [] for name in SCHEMAS}
    def add(table, *values):
        data[table].append(values)
    start = datetime(2018, 1, 1)
    for i, day in enumerate([0, 0, 2, 6, 8, 14, 20, 28, 31, 38, 44], 1):
        oid, cid = f'o{i:03}', f'c{i:03}'
        date = start + timedelta(days=day)
        delivered = date + timedelta(days=3 if i % 2 else 7)
        status = 'canceled' if i == 3 else 'shipped' if i == 4 else 'delivered'
        unique_id = 'repeat_buyer' if i in (1, 2, 11) else f'buyer{i:03}'
        state = 'RJ' if i == 11 else 'SP'
        add('olist_customers_dataset', cid, unique_id, '01001', 'rio' if state == 'RJ' else 'sao paulo', state)
        add('olist_orders_dataset', oid, cid, status, date, date, date + timedelta(days=1),
            delivered if status == 'delivered' else '', '' if i == 5 else date + timedelta(days=5))
        # Order 1: two items, three payments, two reviews. Revenue must stay 165.
        prices = [100, 50] if i == 1 else [i * 10]
        for j, price in enumerate(prices, 1):
            add('olist_order_items_dataset', oid, j, 'p1' if j == 1 else 'p2', 's1', date, price, price / 10)
        if i == 1:
            for j, (kind, value) in enumerate([('credit_card', 100), ('credit_card', 40), ('voucher', 25)], 1):
                add('olist_order_payments_dataset', oid, j, kind, 1, value)
        else:
            add('olist_order_payments_dataset', oid, 1, 'credit_card', 1, sum(prices) * 1.1)
        for j, score in enumerate([1, 5] if i == 1 else [4], 1):
            add('olist_order_reviews_dataset', f'r{i:03}_{j}', oid, score, '', '', date, date + timedelta(days=1))
    # No-item/no-payment/no-review canceled order: retained in order counts.
    add('olist_customers_dataset','c012','buyer012','01001','sao paulo','SP')
    add('olist_orders_dataset','o012','c012','canceled',start+timedelta(days=10),'','','',start+timedelta(days=15))
    add('olist_products_dataset','p1','casa',10,50,2,100,10,10,10)
    add('olist_products_dataset','p2','untranslated',10,50,1,100,10,10,10)
    add('olist_products_dataset','p3','',10,50,1,100,10,10,10)
    add('olist_sellers_dataset','s1','01001','sao paulo','SP')
    add('olist_sellers_dataset','s2','01001','sao paulo','SP')
    add('product_category_name_translation','casa','home')
    for city in ['sao paulo','sao paulo','sp']:
        add('olist_geolocation_dataset','01001',-23.55,-46.63,city,'SP')
    for table, rows in data.items():
        with (directory / f'{table}.csv').open('w', newline='', encoding='utf-8') as f:
            writer=csv.writer(f)
            writer.writerow(SCHEMAS[table])
            writer.writerows(rows)
    return {table: len(rows) for table, rows in data.items()}

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output', default='data/demo')
    print('Synthetic fixture:', generate(parser.parse_args().output))
