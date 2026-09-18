"""One command: create fixture, load, build/test all models and snapshot, export marts."""
import os
from pathlib import Path
import subprocess
import shutil
import sys
from generate_demo import generate
from load_local import load

ROOT = Path(__file__).resolve().parents[1]

def dbt(*args):
    command = [str(Path(sys.executable).with_name('dbt.exe' if os.name == 'nt' else 'dbt')),
               *args, '--profiles-dir', 'profiles', '--target', 'local']
    subprocess.run(command, cwd=ROOT, check=True)

if __name__ == '__main__':
    os.chdir(ROOT)
    if os.environ.get('DBT_DUCKDB_PATH'):
        raise SystemExit('Unset DBT_DUCKDB_PATH before running the fixed-path demo.')
    generate('data/demo')
    print(load('data/demo', 'data/olist.duckdb'))
    dbt('build')
    shutil.copyfile('target/run_results.json','target/build_results.json')
    dbt('docs', 'generate')
    subprocess.run([sys.executable, 'scripts/export_marts.py'], check=True)
