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
assert not (RECORD/'results.json').exists()
shutil.copyfile(__file__,str(RECORD/'controller.py'))
results=[]
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

run('acceptance',['python3','tests/acceptance/run.py','--all','--output-root',OUT/'acceptance'])
sources=sorted((ROOT/'rtl').glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))+sorted((ROOT/'rtl').glob('*.c'))
include=Path(shutil.which('vcs')).resolve().parents[1]/'include'
for example in ['bw_mon_quickstart','bw_mon_grouped']:
    build=OUT/'examples'/example;build.mkdir(parents=True,exist_ok=True)
    command=['vcs','-full64','-sverilog','-error=AOUP','+vpi','-debug_access+all','-assert','svaext',
             '+incdir+'+str(ROOT/'rtl'),'-CFLAGS','-I'+str(include)]+sources+[ROOT/'examples'/(example+'.sv'),'-top',example,'-o',build/'simv']
    run(example+'-compile',command,build)
    assert not re.search(r'(?:Warning|Error)-\[',(RECORD/(example+'-compile.log')).read_text())
    run(example,[build/'simv','-no_save'],build)
    log=(RECORD/(example+'.log')).read_text()
    if example=='bw_mon_quickstart':
        assert 'QUICKSTART window_bytes=640 bandwidth_gbps=64.000 window_valid=1' in log
        assert 'QUICKSTART total_bytes=1280 total_events=20 e2e_gbps=64.000 e2e_valid=1' in log
        assert 'BW_SUMMARY status=WARNING pass=0 fail=0 warning=1 scopes_done=1 scopes_expected=1' in log
    else:
        assert 'GROUPED window0=640 window1=640 window_group=1280 bandwidth_group=128.000 window_valid=1' in log
        assert 'GROUPED total0=2560 total1=2560 total_group=5120 e2e_group=128.000 e2e_valid=1' in log
        assert 'BW_SUMMARY status=PASS pass=3 fail=0 warning=0 scopes_done=3 scopes_expected=3' in log
run('verdi-applicability',['python3','tests/verdi61/applicability.py','--source-root',ROOT,'--acceptance',OUT/'acceptance/steady_ns','--output',OUT/'verdi-applicability'])
run('python-tools',['make','test-evidence-tools'])
run('campaign58',['python3','tests/campaign58/run.py','--evidence',OUT/'campaign58','--lock','/tmp/bw-mon-spec48/acceptance.lock'])
for tier,mode in [('quick','cold'),('quick','hot'),('full','cold'),('full','hot')]:
    run(tier+'-'+mode,['python3','tests/scale/revised_suite.py',tier,'--cache-mode',mode,
                     '--output-root',OUT/'revised','--lock','/tmp/bw-mon-spec48/acceptance.lock'])
run('contracts-final',['python3','tools/contract_campaign.py','--output',OUT/'contracts-campaign'])
