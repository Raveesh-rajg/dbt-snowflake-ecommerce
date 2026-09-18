# Modeling decisions

## Pre-aggregate before joining

Orders, items, payments and reviews have different grains. `fct_orders` aggregates
the latter three independently to order grain. Dimensions and marts reuse that
fact or explicitly aggregate to seller/order or product/order before calculating
reviews. A regression fixture combines two items, three payments and two reviews
in one order, so an accidental many-to-many join is observable.

## Stable customers and current locations

One stable customer may have many `customer_id` values and may change states.
Customer aggregates group only by the stable identity; location is selected from
the latest observed purchase (customer ID breaks timestamp ties). This is a
current-location attribution, not an assertion that every historical purchase
occurred in the current state. The fact retains the order's original location.

## Full daily rebuild instead of incorrect incremental windows

The original incremental predicate removed older rows before evaluating rolling
windows, changing values at the refresh boundary; sparse order dates also made
row-based frames represent sales days instead of calendar days. The replacement
uses a dense calendar and rebuilds the small daily table. It trades an additional
scan of orders for transparent correction handling. A late change older than
30 days is exercised by the regression suite.

At materially larger scale, use change capture to identify affected dates,
read the necessary preceding window, and update every downstream affected date.
Do not add a trailing cutoff merely to advertise incremental processing.

## Snapshots are observation history

The check-strategy snapshot records changes in the mutable order-status feed.
It cannot reconstruct status changes before the first snapshot or changes between
two observations. A static Olist extract only provides an initial state; the demo
changes one order to prove SCD2 behavior. Schemas use the target prefix, so two
environments do not share the snapshot table.

## Local verification and Snowflake portability

DuckDB runs the same dbt models locally; a small weekday macro handles adapter
differences, and date addition uses dbt's built-in dispatch. No external dbt
package is required. A local pass is not proof of Snowflake SQL execution,
warehouse permissions, costs or performance. Those require the live runbook.

## Downstream compatibility

The sibling LookML repository already references nonexistent `CUSTOMER_ID`,
`CUSTOMER_STATE` and `CUSTOMER_CITY` columns in `DIM_CUSTOMERS`. Its integration
must map `CUSTOMER_UNIQUE_ID`, `PRIMARY_STATE`, `PRIMARY_CITY` and use the configured
schema prefix. Its USD formatting also needs to become BRL. This is tracked in
the portfolio audit rather than masked by adding misleading aliases here.
