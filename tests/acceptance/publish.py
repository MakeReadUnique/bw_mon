#!/usr/bin/env python3
"""Validate and package durable acceptance assets, never manufacturing review."""
import argparse,csv,hashlib,io,json,platform,re,shutil,subprocess,tarfile
from pathlib import Path
from evidence import runtime_evidence,scene_runtime_evidence
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/acceptance'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pack',action='store_true');args=p.parse_args();scenes=[];totals={};analysis={};pictures=[];revisions=set()
 runtime=runtime_evidence(ROOT,OUT)
 for directory in sorted(OUT.iterdir()):
  if not (directory/'commands.json').exists():continue
  manifest=json.loads((directory/'commands.json').read_text());comparison=json.loads((directory/'comparison.json').read_text());assert comparison['status']=='PASS' and comparison['human_review']=='PENDING'
  scene_runtime_evidence(ROOT,OUT,directory,manifest,runtime)
  revisions.add(manifest['base_revision'])
  for name,digest in manifest['dependency_sha256'].items():
   path=ROOT/name
   if not path.exists() and name.endswith('/stimulus.txt'):
    with tarfile.open(str(directory/'trace.tar.gz')) as t:actual=hashlib.sha256(t.extractfile('stimulus.txt').read()).hexdigest()
   else:actual=sha(path)
   assert actual==digest,('stale simulation/reference source',directory.name,name)
  paths=set()
  for file in directory.glob('signals-*.json'):paths.update(json.loads(file.read_text())['public_paths'])
  assert paths,directory
  build=ROOT/'.build/acceptance/resolution'/directory.name;build.mkdir(parents=True,exist_ok=True)
  csvpath=build/'resolved.csv';logpath=build/'resolve.log'
  cmd=['fsdbreport',str(directory/'waves.fsdb'),'-s']+sorted(paths)+['-csv','-o',str(csvpath),'-nolog']
  with logpath.open('w') as f:r=subprocess.run(cmd,cwd=str(build),stdout=f,stderr=subprocess.STDOUT)
  assert r.returncode==0,logpath
  with csvpath.open() as f:header=next(csv.reader(f))
  actual={re.sub(r'\[[0-9]+:[0-9]+\]$','',s) for s in header[1:]}
  assert actual==paths,('unresolved public fields',directory.name,sorted(paths-actual),sorted(actual-paths))
  resolution={'status':'PASS','public_signal_count':len(paths),'actual_headers':header,'command':cmd}
  resolution_file=directory/'resolved-signals.json'
  previous_resolution=json.loads(resolution_file.read_text()) if resolution_file.exists() else {}
  if any(previous_resolution.get(key)!=resolution[key] for key in ['status','public_signal_count','actual_headers']):
   resolution_file.write_text(json.dumps(resolution,indent=2)+'\n')
  captured=[]
  for image in directory.glob('*.png'):
   file=directory/('capture-'+image.stem+'-manifest.json')
   if not file.exists():continue
   m=json.loads(file.read_text());assert m['fresh'] and m['pixels']==[1500,850] and m['fsdb_sha256']==sha(directory/'waves.fsdb') and m['png_sha256']==sha(image),('stale capture',image)
   assert m['human_review']=='PENDING'
   captured.append(image.name);pictures.append(str(image.relative_to(OUT)))
  for key,value in comparison['counts'].items():totals[key]=totals.get(key,0)+value
  for key,value in comparison['analysis_counts'].items():analysis[key]=analysis.get(key,0)+value
  scenes.append({'scene':directory.name,'configuration':manifest['configuration'],'counts':comparison['counts'],'analysis_counts':comparison['analysis_counts'],'performance':comparison['report_reference'],'images':captured,'fsdb_sha256':sha(directory/'waves.fsdb'),'human_review_at_generation':comparison['human_review']})
  if args.pack:
   files=list(directory.glob('p*.csv'))+[directory/(n+'.csv') for n in ['die0','die1','all_dmc','mixed']]
   files +=[directory/n for n in ['stimulus.txt','compile.log','run.log','fsdb-values.csv','fsdbreport.log','capture.log','capture.tcl','signals.json','capture-manifest.json','capture.ready']]
   files +=list(directory.glob('*.ready'))+list(directory.glob('capture-*.log'))
   files=sorted({f for f in files if f.exists()})
   if files:
    previous={}
    archive_path=directory/'trace.tar.gz'
    if archive_path.exists():
     with tarfile.open(str(archive_path)) as old:
      previous={m.name:(m,old.extractfile(m).read()) for m in old.getmembers() if m.isfile()}
    for file in files:previous[file.name]=(None,file.read_bytes())
    with tarfile.open(str(archive_path),'w:gz') as archive:
     for name,(info,data) in sorted(previous.items()):
      if info is None:info=tarfile.TarInfo(name);info.size=len(data);info.mode=0o644
      archive.addfile(info,io.BytesIO(data))
    for file in files:file.unlink()
   for file in directory.glob('*.md'):
    text=file.read_text().replace('(stimulus.txt)','(trace.tar.gz)').replace('(run.log)','(trace.tar.gz)').replace('(fsdb-values.csv)','(trace.tar.gz)');file.write_text(text)
 for file in (OUT/'component-proof').glob('*.tar.gz'):assert file.stat().st_size>0
 assert len(scenes)==42,len(scenes)
 previous_review=json.loads((OUT/'review.json').read_text()) if (OUT/'review.json').exists() else {}
 review_objects=[]
 for directory in OUT.iterdir():
  if not (directory/'commands.json').exists():continue
  review_objects +=[f for f in directory.iterdir() if f.is_file() and (f.suffix in ['.fsdb','.png','.sav','.cfg'] or f.name in ['expected-actual.md','reference.json','commands.json'] or f.name.startswith('signals-'))]
 fingerprint=hashlib.sha256(json.dumps([(str(f.relative_to(OUT)),sha(f)) for f in sorted(review_objects)],sort_keys=True).encode()).hexdigest()
 review={'human':{'status':'PENDING','reviewer':None,'date':None,'objects_intervals_conclusion':None},'agent':{'status':'PENDING','note':'Agent inspection is not human attestation'},'actual_images':pictures,'instructions':'Read INDEX and each independent expected-actual table; inspect original FSDB/public views/images. Record exact reviewer/date/scope/interval/expected/actual/differences. No sign-off on future assets.'}
 if 'previous_human_record' in previous_review:review['previous_human_record']=previous_review['previous_human_record']
 if previous_review.get('human',{}).get('status','PENDING')!='PENDING':
  if previous_review.get('asset_fingerprint')==fingerprint:review['human']=previous_review['human']
  else:review['previous_human_record']=previous_review['human'];review['human']['reason']='Assets changed; prior attestation does not cover new assets'
 if 'previous_agent_record' in previous_review:review['previous_agent_record']=previous_review['previous_agent_record']
 if 'agent' in previous_review:
  if previous_review.get('asset_fingerprint')==fingerprint:review['agent']=previous_review['agent']
  elif previous_review['agent'].get('status')!='PENDING':review['previous_agent_record']=previous_review['agent']
 review['asset_fingerprint']=fingerprint
 (OUT/'review.json').write_text(json.dumps(review,indent=2)+'\n')
 human_status=review['human']['status']
 (OUT/'verification.json').write_text(json.dumps({'status':'PASS','production_base':runtime['head'],'harness_revisions':sorted(revisions),'runtime_source_manifest':'runtime-source.json','runtime_source_unchanged':True,'current_component_proof':'current-component-proof/verification.json','historical_component_proof':'component-proof/verification.json','scenes':scenes,'totals':totals,'analysis_totals':analysis,'fresh_actual_pngs':len(pictures),'human_review':human_status,'human_review_scope':'Only named objects and intervals in review.json; no per-scene approval inferred','python':platform.python_version(),'window_real_tolerance_gbps':1e-10,'metric_real_tolerance':1e-8,'formal_tolerance':'cfg only; no hidden epsilon'},indent=2)+'\n')
 index='# Actual12-point/four-group acceptance assets\n\nAutomated **42/42PASS**; **human T6 ledger status: '+human_status+'**. Agent image inspection is separate.\n\n'
 index+='Human status covers only the ledger\'s named objects and intervals. Scene rows describe automated results only; no per-scene human approval is inferred. PENDING entries in original comparison/capture/table files record generation-time state.\n\n'
 index+='Independent totals: '+str(totals)+'; analysis: '+str(analysis)+'. Original FSDBs and images are unchanged. [D17handoff/commands](../../docs/bw-mon-acceptance.md) · [machine proof](verification.json) · [concrete human checklist](HUMAN-REVIEW.md) · [human/agent ledger](review.json) · [public fields](public-fields.json) · [error index](error-catalog.json).\n\n'
 index+='This campaign consumes the [frozen runtime and native dependency hashes](runtime-source.json), with [current 424-case /167-top /3 minimum-option component proof](current-component-proof/verification.json). Its [portable archives and verifier](current-component-proof/README.md) are retained here. The unchanged [historical 408-case component proof](component-proof/verification.json) and [historical log/config archive](component-proof/final-408-proof.tar.gz) describe their original source, not the current runtime. Scale evidence is separately scoped by its own manifests.\n\n|Scene|Basis W/S/Q|Original data and independent table|Actual screenshots|Automated performance summary|\n|---|---|---|---|---|\n'
 for s in scenes:
  name=s['scene'];c=s['configuration'];imgs=' '.join('['+i+']('+name+'/'+i+')' for i in s['images']) or 'Portable public views; FSDB directly available'
  index+='|%s|%s %s/%s/%s|[FSDB](%s/waves.fsdb) · [expected/actual](%s/expected-actual.md) · [reference](%s/reference.json) · [cfg](%s/expect.cfg) · [open](%s/open.sh)|%s|%s %s|\n'%(name,c['basis'],c['W'],c['S'],c['Q'],name,name,name,name,name,imgs,s['performance']['summary_status'],s['performance']['expected'])
 index+='\nThe trace.tar.gz beside each scene retains original raw inputs/CSV and compiler/runtime/capture logs. commands.json records source/header/oracle/cfg hashes and exact commands. Portable views use nearby waves.fsdb; `./open.sh <view>` opens one without former worktree/build dependencies. Actual signal paths were independently resolved from every FSDB. Numeric real rows use Scientific10 for boundary readability.\n'
 (OUT/'INDEX.md').write_text(index)
 inventory={str(f.relative_to(OUT)):sha(f) for f in OUT.rglob('*') if f.is_file() and f.name!='SHA256SUMS.json'}
 (OUT/'SHA256SUMS.json').write_text(json.dumps(inventory,indent=2,sort_keys=True)+'\n')
 print('PASS durable assets:',len(scenes),'scenes',totals,analysis,len(pictures),'fresh realimages',flush=True)
if __name__=='__main__':main()
