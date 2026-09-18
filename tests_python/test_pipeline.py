"""Integration regressions execute the real dbt DAG on adversarial fixture data."""
from pathlib import Path
import os
import subprocess
import sys
import csv
import shutil
import duckdb
import pytest
from generate_demo import generate
from load_local import load
from data_contract import validate_files

ROOT = Path(__file__).resolve().parents[1]

def build(database, *selection):
    env=os.environ.copy()
    env['DBT_DUCKDB_PATH']=str(database)
    exe=Path(sys.executable).with_name('dbt.exe' if os.name=='nt' else 'dbt')
    result=subprocess.run([str(exe),'build','--profiles-dir','profiles','--target','local',
                           '--target-path',str(database.parent/'dbt-artifacts'),*selection],
                          cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8')
    assert result.returncode==0, result.stdout+'\n'+result.stderr

@pytest.fixture(scope='module')
def warehouse(tmp_path_factory):
    directory=tmp_path_factory.mktemp('olist')
    generate(directory/'csv')
    database=directory/'test.duckdb'
    load(directory/'csv',database)
    build(database)
    return database

def query(database, sql):
    with duckdb.connect(str(database),read_only=True) as con:
        return con.execute(sql).fetchall()

def test_multiple_reviews_and_split_payments_do_not_multiply_money(warehouse):
    row=query(warehouse,"select total_items,total_revenue,total_paid,avg_review_score,primary_payment_type,days_vs_estimate from analytics_marts.fct_orders where order_id='o001'")[0]
    assert tuple(float(x) if i in (1,2,3) else x for i,x in enumerate(row))==(2,165,165,3,'credit_card',-2)

def test_customer_identity_survives_move(warehouse):
    row=query(warehouse,"select lifetime_orders,lifetime_revenue,customer_state from analytics_marts.mart_customer_lifetime_value where customer_unique_id='repeat_buyer'")[0]
    assert row==(3,308,'RJ')

def test_sparse_days_have_calendar_rolling_windows(warehouse):
    assert query(warehouse,'select count(*) from analytics_marts.mart_daily_revenue')[0][0]==45
    row=query(warehouse,"select daily_revenue,revenue_7day_sum,revenue_7day_avg from analytics_marts.mart_daily_revenue where order_date='2018-01-07'")[0]
    assert row[0]==0 and row[1]==187 and float(row[2])==26.71

def test_seller_metrics_are_order_weighted(warehouse):
    row=query(warehouse,"select orders_fulfilled,items_sold,on_time_delivery_pct,avg_review,negative_review_count from analytics_marts.mart_seller_performance where seller_id='s1'")[0]
    assert row[0:2]==(9,10)
    assert float(row[2])==50
    assert float(row[3])==3.89
    assert row[4]==1

def test_missing_delivery_is_not_success_and_zip_is_preserved(warehouse):
    assert query(warehouse,"select was_delivered_late from analytics_marts.fct_orders where order_id='o005'")==[(None,)]
    assert query(warehouse,"select customer_zip_code_prefix from analytics_staging.stg_customers limit 1")==[('01001',)]
    assert query(warehouse,"select total_items,total_revenue from analytics_marts.fct_orders where order_id='o012'")==[(0,0)]

def test_rerun_is_idempotent(warehouse):
    before=query(warehouse,'select * from analytics_marts.mart_daily_revenue order by order_date')
    build(warehouse)
    assert query(warehouse,'select * from analytics_marts.mart_daily_revenue order by order_date')==before
    assert query(warehouse,'select count(*) from analytics_snapshots.snap_orders_status')==[(12,)]

def test_historical_correction_and_snapshot_change(warehouse, tmp_path):
    baseline = warehouse
    warehouse = tmp_path / 'changed.duckdb'
    shutil.copy2(baseline, warehouse)
    with duckdb.connect(str(warehouse)) as con:
        con.execute("update raw.olist_order_items_dataset set price=200 where order_id='o001' and order_item_id=1")
        con.execute("update raw.olist_orders_dataset set order_status='delivered',order_delivered_customer_date='2018-01-08' where order_id='o004'")
    build(warehouse)
    assert query(warehouse,"select daily_revenue from analytics_marts.mart_daily_revenue where order_date='2018-01-01'")==[(287,)]
    history=query(warehouse,"select order_status,dbt_valid_to is null from analytics_snapshots.snap_orders_status where order_id='o004' order by dbt_valid_from")
    assert history==[('shipped',False),('delivered',True)]
    build(warehouse,'--select','snap_orders_status')
    assert query(warehouse,"select count(*) from analytics_snapshots.snap_orders_status where order_id='o004'")==[(2,)]

def test_loader_rejects_header_drift_before_writing(tmp_path):
    generate(tmp_path)
    path=tmp_path/'olist_orders_dataset.csv'
    path.write_text('wrong_column\n1\n',encoding='utf-8')
    with pytest.raises(ValueError,match='expected columns'):
        validate_files(tmp_path)

def test_loader_rolls_back_all_tables_on_bad_value(tmp_path):
    generate(tmp_path/'csv')
    database=tmp_path/'rollback.duckdb'
    load(tmp_path/'csv',database)
    path=tmp_path/'csv/olist_order_items_dataset.csv'
    rows=list(csv.reader(path.open(encoding='utf-8')))
    rows[1][5]='not_money'
    with path.open('w',encoding='utf-8',newline='') as f:
        csv.writer(f).writerows(rows)
    with pytest.raises(duckdb.Error):
        load(tmp_path/'csv',database)
    assert query(database,'select count(*) from raw.olist_orders_dataset')==[(12,)]
    assert query(database,"select price from raw.olist_order_items_dataset where order_id='o001' and order_item_id=1")==[(100,)]
