"""
Load Olist CSV files into Snowflake's OLIST_DB.RAW schema.

Reads each CSV from data/raw/, infers a schema, and bulk-loads to Snowflake.
Idempotent: existing tables are dropped and recreated each run.

Usage:
    python scripts/load_raw_data.py
"""

import os
import sys
import yaml
import time
from pathlib import Path

import pandas as pd
from snowflake.connector import connect
from snowflake.connector.pandas_tools import write_pandas


# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
DATA_DIR = Path("data/raw")
PROFILES_PATH = Path.home() / ".dbt" / "profiles.yml"
PROFILE_NAME = "dbt_snowflake_ecommerce"
TARGET_NAME = "dev"
TARGET_DATABASE = "OLIST_DB"
TARGET_SCHEMA = "RAW"


def load_snowflake_creds():
    """Read credentials from ~/.dbt/profiles.yml — avoids duplicating secrets."""
    with open(PROFILES_PATH) as f:
        profiles = yaml.safe_load(f)
    target = profiles[PROFILE_NAME]["outputs"][TARGET_NAME]
    return {
        "account": target["account"],
        "user": target["user"],
        "password": target["password"],
        "role": target["role"],
        "warehouse": target["warehouse"],
        "database": TARGET_DATABASE,
        "schema": TARGET_SCHEMA,
    }


def csv_to_table_name(csv_path: Path) -> str:
    """olist_orders_dataset.csv -> OLIST_ORDERS_DATASET"""
    return csv_path.stem.upper()


def load_csv_to_snowflake(conn, csv_path: Path) -> tuple[str, int, float]:
    """Read CSV, push to Snowflake. Returns (table_name, row_count, seconds)."""
    table = csv_to_table_name(csv_path)
    start = time.time()

    df = pd.read_csv(csv_path)
    # Normalize column names: lowercase, no spaces, no special chars
    df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]

    # write_pandas creates the table if it doesn't exist and bulk-loads via PUT/COPY
    success, n_chunks, n_rows, _ = write_pandas(
        conn=conn,
        df=df,
        table_name=table,
        database=TARGET_DATABASE,
        schema=TARGET_SCHEMA,
        auto_create_table=True,
        overwrite=True,  # idempotent: replaces existing table
    )

    elapsed = time.time() - start
    if not success:
        raise RuntimeError(f"Failed to load {table}")
    return table, n_rows, elapsed


def main():
    if not DATA_DIR.exists():
        print(f"ERROR: {DATA_DIR} not found. Did you download the Olist dataset?")
        sys.exit(1)

    csv_files = sorted(DATA_DIR.glob("*.csv"))
    if not csv_files:
        print(f"ERROR: No CSV files in {DATA_DIR}")
        sys.exit(1)

    print(f"Found {len(csv_files)} CSV file(s) to load.\n")

    creds = load_snowflake_creds()
    conn = connect(**creds)

    total_rows = 0
    try:
        for csv_path in csv_files:
            print(f"  Loading {csv_path.name} ...", end=" ", flush=True)
            table, n_rows, elapsed = load_csv_to_snowflake(conn, csv_path)
            total_rows += n_rows
            print(f"-> {table}: {n_rows:,} rows in {elapsed:.1f}s")
    finally:
        conn.close()

    print(f"\nDone. Loaded {total_rows:,} total rows across {len(csv_files)} tables into {TARGET_DATABASE}.{TARGET_SCHEMA}")


if __name__ == "__main__":
    main()