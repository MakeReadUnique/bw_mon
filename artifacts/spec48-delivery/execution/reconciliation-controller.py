import hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
root=Path('/home/eda/bw_cal');source=Path('/home/eda/bw-mon-ticket62-candidate-source');runs=Path('/home/eda/bw-mon-ticket62-candidate-runs');records=Path('/tmp/bw-mon-ticket62/candidate')
old=json.loads((records/'results.json').read_text());assert len(old)==13 and old[-1]['name']=='contracts-final' and old[-1]['exit_code']==1
prior=records/'prior-attempts/contract-inventory';prior.mkdir()
for name in ['results.json','contracts-final.log']:shutil.copyfile(str(records/name),str(prior/name))
original=runs/'contracts-campaign';report=json.loads((original/'campaign.json').read_text());assert all(j['exit_code']==0 for j in report['jobs'])
command=[sys.executable,str(root/'tools/contract_campaign.py'),'--reconcile-recorded',str(original),'--source',str(source),'--output',str(runs/'contracts-campaign-reconciled')]
shutil.copyfile(__file__,str(records/'reconciliation-controller.py'));start=time.monotonic()
with (records/'contracts-final.log').open('w') as stream:p=subprocess.run(command,cwd=str(root),stdout=stream,stderr=subprocess.STDOUT)
row=dict(name='contracts-final',command=command,cwd=str(root),exit_code=p.returncode,elapsed_seconds=time.monotonic()-start,
         mode='reconcile-original-native-shards',original_native_campaign_seconds=report['elapsed_seconds'],
         original_controller_exit_code=old[-1]['exit_code'],original_controller_seconds=old[-1]['elapsed_seconds'],
         original_campaign_sha256=hashlib.sha256((original/'campaign.json').read_bytes()).hexdigest(),
         note='Native shards all exited zero and retain their original logs and timing. The original inventory parser rejected an existing hyphenated case name; only post-processing is rerun.')
(records/'reconciliation-result.json').write_text(json.dumps(row,indent=2)+'\n')
print(json.dumps(row),flush=True)
if p.returncode:raise SystemExit(p.returncode)
(records/'results.json').write_text(json.dumps(old[:-1]+[row],indent=2)+'\n')
