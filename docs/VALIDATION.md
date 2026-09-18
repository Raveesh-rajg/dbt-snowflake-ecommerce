# Validation record

Verified locally on 2026-09-18 with Python 3.12, dbt-core 1.11.11,
dbt-duckdb 1.10.1 and DuckDB 1.5.5. Fixtures are synthetic, deterministic and
deliberately small; these results are not performance benchmarks.

Commands:

```bash
python scripts/run_demo.py
python -m pytest -q
```

- Complete dbt build: **17 models, 1 snapshot, 73 data tests**, all passing.
- dbt documentation: manifest/catalog generated successfully.
- Three CSV exports: **45 daily rows, 7 customer rows, 1 seller row**.
- Python integration suite: **9 tests passed**. It reruns the actual dbt DAG in
  a temporary warehouse, then checks independently known fixture expectations.
- A Snowflake-target `dbt parse` was also run with placeholder profile identifiers.
  This verifies project/Jinja/YAML parsing only; it does not validate Snowflake
  query execution or connectivity.

## Regression coverage

1. Multi-review, multi-item, split-payment order does not inflate money; mode and
   negative early-delivery offset are correct.
2. Repeat customer moving from SP to RJ remains one customer, with the latest state.
3. Sparse purchases produce zero-sales calendar rows and a correct seven-day window.
4. Seller metrics weight reviews once per order and use the observed-delivery denominator.
5. Missing delivery estimate remains unknown; leading-zero ZIP and no-item order survive.
6. Rebuilding changes neither daily results nor unchanged snapshot row count.
7. A historical correction updates the daily mart; one status change creates exactly
   two SCD2 versions, exactly one current; another snapshot does not duplicate history.
8. CSV header drift is rejected before any write.
9. Invalid numeric input rolls back all local raw tables.

## What remains unverified

Full Olist extract quality and volume; Snowflake compilation/execution, cost and
runtime; Snowflake raw loading with a real account; Tableau workbook/publication;
and production schedules, deletion handling and access controls. These are explicit
next-stage tasks, not hidden behind the successful local build. Snapshot history
starts with the first observation and cannot reconstruct prior source changes.
