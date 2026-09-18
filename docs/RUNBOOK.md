# Operating the warehouse

## Local demo and real CSVs

Run the quickstart in the README for synthetic data. To use the full Olist CSVs,
place the nine original files (including category translation) in `data/raw/`:

```bash
python scripts/load_local.py --data-dir data/raw --database data/olist.duckdb
dbt build --profiles-dir profiles --target local
dbt docs generate --profiles-dir profiles --target local
python scripts/export_marts.py
```

The local loader validates the complete file/header contract before writing,
applies explicit data types, and replaces all nine tables in one transaction.
Malformed values roll back the complete load. Stop dbt/BI connections before
replacing the database. Do not run `run_demo.py` on a real-data checkout unless
you intend to replace its local raw tables with the demo fixture.

dbt schemas default to `raw`, `analytics_staging`, `analytics_marts` and
`analytics_snapshots`. Data paths are ignored by Git. Preserve your DuckDB file
if snapshot history matters; recreating it loses observation history.

## Snowflake: separate, not yet executed

1. Create the database/warehouse using `sql/setup/01_create_database_and_schemas.sql`
   with an administrative role. Assign a dedicated role to your user with warehouse
   USAGE, database USAGE/CREATE SCHEMA, and RAW schema USAGE/CREATE TABLE plus read
   access to its tables. The setup file does not assign your user automatically.
2. In a separate virtual environment install `requirements-snowflake.txt`.
3. Set `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`,
   `SNOWFLAKE_WAREHOUSE`, and optionally `SNOWFLAKE_DATABASE` (default `OLIST_DB`).
   `externalbrowser` is the default authenticator for the loader and dbt profile.
   Enter credentials only in Snowflake's browser flow. For a service account,
   configure a separate approved key-pair/OAuth profile outside Git.
4. Put the original CSVs in `data/raw/`, then run:

```bash
python scripts/load_raw_data.py --data-dir data/raw
dbt debug --profiles-dir profiles --target snowflake
dbt build --profiles-dir profiles --target snowflake
dbt docs generate --profiles-dir profiles --target snowflake
```

The Snowflake loader refuses to replace existing destination tables by default.
Pass `--replace` deliberately when reloading. It first loads a temporary table,
checks the row count, then replaces each destination. Multi-table replacement is
not atomic in Snowflake; after any failure, rerun all tables before dbt.

Snowflake raw tables use VARCHAR to preserve the source representation; staging
casts fields explicitly. Local raw data uses the matching typed CSV contract.
Model schemas default to `ANALYTICS_STAGING`, `ANALYTICS_MARTS`, and
`ANALYTICS_SNAPSHOTS`, **not** the bootstrap script's bare STAGING/MARTS schemas.
Use `DBT_SCHEMA` to isolate environments. Keep RAW source selection explicit via
`--vars '{raw_schema: RAW}'` when using a different raw schema.

Capture row counts, dbt run artifacts, query history and actual credit usage
after a successful live run. No estimated savings should be presented as measured.

## BI handoff

Local CSV exports: daily revenue, customer historical value and seller performance.
In Snowflake, execute the SELECTs in `sql/export_marts.sql` and download each
result as CSV. Use one source per page; joining the three marts multiplies rows.
Recommended pages: daily delivered order value and trend; customer concentration;
seller revenue vs review/delivery quality. Currency is BRL, not USD. The source
provenance label must say "synthetic demo" or identify the real extract date.

A Tableau workbook/publication remains a separate deliverable. CSV exports and
dbt documentation are delivered here; a dashboard specification is not a dashboard.

## CI and failures

CI runs the full local DAG, snapshots, docs, exports and regression suite without
secrets. Download `dbt-local-evidence` from the workflow. Fix failing tests before
using marts. Build results, compiled SQL and lineage are under `target/`.
Tests use a separate temporary warehouse, never the user's demo/real database.
