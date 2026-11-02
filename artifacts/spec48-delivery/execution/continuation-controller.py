import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT=Path('/home/eda/bw-mon-ticket62-candidate-source')
OUT=Path('/home/eda/bw-mon-ticket62-candidate-runs')
RECORD=Path('/tmp/bw-mon-ticket62/candidate')
RECORD.mkdir(exist_ok=True)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,universal_newlines=True).strip()=='154d45f2ba32242cd728c9996157cee296491fa2'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip()
prior=RECORD/'prior-attempts/missing-common';prior.mkdir()
for name in ['results.json','full-cold.log','controller.py']:
    shutil.copyfile(str(RECORD/name),str(prior/name))
results=json.loads((RECORD/'results.json').read_text())
assert results[-1]['name']=='full-cold' and results[-1]['exit_code']!=0
results=results[:-1]
assert len(results)==10 and all(row['exit_code']==0 and row.get('budget_met',True) for row in results)
shutil.copyfile(__file__,str(RECORD/'continuation-controller.py'))
shutil.copyfile('/tmp/bw-mon-ticket62/full-suite-command.py',str(RECORD/'full-suite-command.py'))
def run(name,command,cwd=ROOT):
    start=time.monotonic()
    print(datetime.datetime.now(datetime.timezone.utc).isoformat(),name,flush=True)
    with (RECORD/(name+'.log')).open('w') as stream:
        p=subprocess.run([str(x) for x in command],cwd=cwd,stdout=stream,stderr=subprocess.STDOUT)
    row=dict(name=name,command=[str(x) for x in command],cwd=str(cwd),exit_code=p.returncode,elapsed_seconds=time.monotonic()-start)
    budget={'campaign58':900,'quick-cold':300,'quick-hot':120,'full-cold':1800,'full-hot':1800}.get(name)
    if budget is not None:row.update(budget_seconds=budget,budget_met=row['elapsed_seconds']<=budget)
    results.append(row);(RECORD/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(row),flush=True)
    if p.returncode or not row.get('budget_met',True):raise SystemExit('STOP: '+name+' failed; actual result retained')

for mode in ['cold','hot']:
    run('full-'+mode,['python3','/tmp/bw-mon-ticket62/full-suite-command.py','--mode',mode,'--root',ROOT,'--output',OUT/'revised'])
run('contracts-final',['python3','tools/contract_campaign.py','--output',OUT/'contracts-campaign'])
