"""Export independent marts for BI. Each CSV stays at its documented grain."""
import argparse
from pathlib import Path
import duckdb

def export(database, directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(database), read_only=True) as con:
        for table, key in [('mart_daily_revenue','order_date'),
                           ('mart_customer_lifetime_value','customer_unique_id'),
                           ('mart_seller_performance','seller_id')]:
            rows = con.sql(f'SELECT * FROM analytics_marts.{table} ORDER BY {key}')
            rows.write_csv(str(directory / f'{table}.csv'), header=True)
            print(f'{table}: {rows.count("*").fetchone()[0]} rows')

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--database', default='data/olist.duckdb')
    parser.add_argument('--output', default='data/exports')
    args=parser.parse_args()
    export(args.database,args.output)
