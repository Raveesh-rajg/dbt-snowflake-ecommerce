"""Load all nine CSVs atomically into a local DuckDB raw schema."""
import argparse
from pathlib import Path
import duckdb
from data_contract import SCHEMAS, validate_files

def load(directory, database):
    paths = validate_files(directory)  # Validate everything before touching the warehouse.
    Path(database).parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(database)) as con:
        con.execute('BEGIN')
        try:
            con.execute('CREATE SCHEMA IF NOT EXISTS raw')
            counts = {}
            for path in paths:
                table = path.stem
                frame = con.read_csv(str(path), header=True, columns=SCHEMAS[table], na_values='')
                frame.create_view('_incoming', replace=True)
                con.execute(f'CREATE OR REPLACE TABLE raw.{table} AS SELECT * FROM _incoming')
                counts[table] = con.execute(f'SELECT count(*) FROM raw.{table}').fetchone()[0]
            con.execute('COMMIT')
        except Exception:
            con.execute('ROLLBACK')
            raise
    return counts

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--data-dir', default='data/demo')
    parser.add_argument('--database', default='data/olist.duckdb')
    args=parser.parse_args()
    print(load(args.data_dir, args.database))
