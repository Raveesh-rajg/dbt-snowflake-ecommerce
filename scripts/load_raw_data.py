"""Load Olist CSVs into Snowflake. --replace explicitly replaces existing tables.

Uses environment variables with browser authentication, never stored credentials.
Tables load separately; rerun a failed load before dbt (Snowflake DDL is not atomic).
"""
import argparse
import os
import re
from data_contract import SCHEMAS, validate_files

def identifier(value):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', value):
        raise ValueError('Identifiers must contain only letters, digits and underscores')
    return value.upper()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--data-dir', default='data/raw')
    parser.add_argument('--schema', default='RAW')
    parser.add_argument('--replace', action='store_true')
    args=parser.parse_args()
    paths=validate_files(args.data_dir)
    import pandas as pd
    from snowflake.connector import connect
    from snowflake.connector.pandas_tools import write_pandas
    database=identifier(os.environ.get('SNOWFLAKE_DATABASE','OLIST_DB'))
    schema=identifier(args.schema)
    kwargs=dict(account=os.environ['SNOWFLAKE_ACCOUNT'],user=os.environ['SNOWFLAKE_USER'],
                authenticator=os.environ.get('SNOWFLAKE_AUTHENTICATOR','externalbrowser'),
                role=os.environ.get('SNOWFLAKE_ROLE','OLIST_ANALYST'),
                warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE','DEV_WH'),database=database,schema=schema)
    with connect(**kwargs) as conn:
        for path in paths:
            table=identifier(path.stem)
            frame=pd.read_csv(path,dtype=str,keep_default_na=False).replace('',None)
            frame.columns=[c.upper() for c in frame.columns]
            temporary=table+'_LOAD'
            columns=', '.join(f'{identifier(c)} VARCHAR' for c in SCHEMAS[path.stem])
            conn.cursor().execute(f'CREATE OR REPLACE TEMPORARY TABLE {temporary} ({columns})')
            success,_,count,_=write_pandas(conn,frame,temporary,database=database,schema=schema)
            if not success or count!=len(frame):
                raise RuntimeError(f'Incomplete load: {table}')
            create='CREATE OR REPLACE TABLE' if args.replace else 'CREATE TABLE'
            conn.cursor().execute(f'{create} {table} AS SELECT * FROM {temporary}')
            print(f'{database}.{schema}.{table}: {count} rows')

if __name__=='__main__':
    main()
