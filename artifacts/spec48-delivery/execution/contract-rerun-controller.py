import gzip,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
root=Path('/home/eda/bw_cal');source=Path('/home/eda/bw-mon-ticket62-candidate-source');runs=Path('/home/eda/bw-mon-ticket62-candidate-runs');records=Path('/tmp/bw-mon-ticket62/candidate')
original_records=records/'prior-attempts/contract-inventory/results.json';rows=json.loads(original_records.read_text());assert len(rows)==13 and rows[-1]['exit_code']==1
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=str(source),universal_newlines=True).strip()=='154d45f2ba32242cd728c9996157cee296491fa2'
assert not subprocess.check_output(['git','status','--porcelain'],cwd=str(source)).strip()
shutil.copyfile(str(records/'results.json'),str(records/'prior-attempts/contract-inventory/experimental-selected-results.json'))
(records/'results.json').write_bytes(original_records.read_bytes())
old=runs/'contracts-campaign';failed=runs/'contracts-campaign-inventory-failed';old.rename(failed)
backups=records/'prior-attempts/contract-inventory/native-logs';backups.mkdir();inventory={}
for path in (source/'.build/tests').rglob('*'):
 if path.is_file() and (path.suffix=='.log' or path.name=='source.sha256'):
  data=path.read_bytes();relative=path.relative_to(source/'.build/tests');target=backups/(str(relative)+'.gz');target.parent.mkdir(parents=True,exist_ok=True)
  with target.open('wb') as raw:
   with gzip.GzipFile(filename='',fileobj=raw,mode='wb',mtime=0,compresslevel=1) as stream:stream.write(data)
  inventory[str(relative)]=hashlib.sha256(data).hexdigest()
(backups/'index.json').write_text(json.dumps(inventory,indent=2)+'\n')
command=[sys.executable,str(root/'tools/contract_campaign.py'),'--source',str(source),'--output',str(old)]
shutil.copyfile(__file__,str(records/'contract-rerun-controller.py'));start=time.monotonic()
with (records/'contracts-final.log').open('w') as stream:p=subprocess.run(command,cwd=str(root),stdout=stream,stderr=subprocess.STDOUT)
row=dict(name='contracts-final',command=command,cwd=str(root),exit_code=p.returncode,elapsed_seconds=time.monotonic()-start,
         driver_commit='52dbac4',runtime_snapshot='154d45f2ba32242cd728c9996157cee296491fa2',mode='complete-native-cold-shards')
(records/'results.json').write_text(json.dumps(rows[:-1]+[row],indent=2)+'\n')
print(json.dumps(row),flush=True)
raise SystemExit(p.returncode)
