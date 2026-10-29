#!/usr/bin/env python3
"""Recheck portable acceptance archives and genuine assets without simulation."""
import argparse,hashlib,json,subprocess,sys,tarfile,tempfile
from pathlib import Path
from model import require_scene_inventory
from evidence import runtime_evidence,scene_runtime_evidence,dependency_bytes,runtime_sources,project_sources
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/acceptance'
sha=lambda b:hashlib.sha256(b).hexdigest()

def replay_recorded_reference(sources,manifest,work):
 """Keep old source identities and old policies separate from new product runs."""
 with tempfile.TemporaryDirectory(prefix='acceptance-recorded-oracle-') as temporary:
  source=Path(temporary)
  for name,data in sources.items():
   if name.startswith('tests/acceptance/') and name.endswith('.py'):
    target=source/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
  metadata=source/'manifest.json';metadata.write_text(json.dumps(manifest))
  script='''import inspect,json,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import model
from analysis import verify,verify_reports
from run import check_trace
m=json.loads(Path(sys.argv[2]).read_text());work=Path(sys.argv[3]);c=m['configuration']
rows=[[int(v) for v in line.split()] for line in (work/'stimulus.txt').read_text().splitlines()]
expected=model.configuration(c['scene'],c['basis'])
if m.get('input_time_basis')=='offset from published measurement start':
 expected,rows=model.at_measurement_start(expected,rows,c['start_ticks'])
assert c==expected, 'recorded input configuration differs from consumed reference'
frames=model.frame_table(rows);windows=model.window_table(c,rows,frames);log=(work/'run.log').read_text()
result=verify(c,rows,frames,windows,log)
cfg=(work/'expect.cfg').read_text()
if len(inspect.signature(verify_reports).parameters)>6:
 report=verify_reports(c,rows,frames,windows,log,cfg,result.get('default_checks'))
else:
 report=verify_reports(c,rows,frames,windows,log,cfg)
print(json.dumps(dict(basic=check_trace(c,work,rows),analysis=result,report=report)))
'''
  checked=subprocess.run([sys.executable,'-B','-c',script,str(source/'tests/acceptance'),str(metadata),str(work)],
                         stdout=subprocess.PIPE,stderr=subprocess.STDOUT,universal_newlines=True)
  assert checked.returncode==0,('recorded independent reference failed',checked.stdout)
  return json.loads(checked.stdout)

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--current-source',action='store_true',help='also require every scene runtime to equal this checkout');args=parser.parse_args()
 inventory=json.loads((OUT/'SHA256SUMS.json').read_text())
 for name,digest in inventory.items():assert sha((OUT/name).read_bytes())==digest,('asset hash',name)
 runtime=runtime_evidence(ROOT,OUT)
 assert sha((OUT/'component-proof/final-408-proof.tar.gz').read_bytes())=='4eb443a37683d7be6dc669caab4121089a13cd5b751a2da9855434042b6cc6e7'
 total={};metrics={};images=0;scenes=0;configurations=[]
 for folder in sorted(OUT.iterdir()):
  if not (folder/'commands.json').exists():continue
  m=json.loads((folder/'commands.json').read_text());c=m['configuration'];configurations.append(c)
  consumed=scene_runtime_evidence(ROOT,OUT,folder,m,runtime)
  if args.current_source:assert consumed['rtl_sha256']==runtime_sources(ROOT),('recorded runtime differs from current source',folder.name,consumed['head'])
  with tempfile.TemporaryDirectory(prefix='acceptance-audit-') as name:
   work=Path(name)
   with tarfile.open(str(folder/'trace.tar.gz')) as archive:
    for member in archive.getmembers():
     assert member.isfile() and Path(member.name).name==member.name,'unexpected archive path'
     (work/member.name).write_bytes(archive.extractfile(member).read())
   (work/'expect.cfg').write_bytes((folder/'expect.cfg').read_bytes())
   log=(work/'run.log').read_text()
   assert 'TB_PASS acceptance' in log and 'Fatal:' not in log and 'Error-[' not in log and 'BW_CFG WARNING' not in log
   assert 'Warning-[' not in (work/'compile.log').read_text() and 'Error-[' not in (work/'compile.log').read_text()
   replay=replay_recorded_reference(project_sources(OUT,folder,m),m,work)
   basic,result,report=replay['basic'],replay['analysis'],replay['report']
   recorded=json.loads((folder/'comparison.json').read_text());assert result==recorded['analysis_counts'] and report==recorded['report_reference'] and basic['counts']==recorded['counts']
   for path,digest in m['dependency_sha256'].items():
    data=dependency_bytes(ROOT,OUT,folder,m,path)
    assert data is not None and sha(data)==digest,('source/input/cfg hash',folder,path)
  assert json.loads((folder/'resolved-signals.json').read_text())['status']=='PASS'
  for picture in folder.glob('*.png'):
   meta=folder/('capture-'+picture.stem+'-manifest.json')
   if not meta.exists():continue
   x=json.loads(meta.read_text());assert x['fresh'] and x['pixels']==[1500,850] and x['png_sha256']==sha(picture.read_bytes()) and x['fsdb_sha256']==sha((folder/'waves.fsdb').read_bytes());images+=1
  for key,value in basic['counts'].items():total[key]=total.get(key,0)+value
  for key,value in result.items():
   if isinstance(value,dict):
    nested=metrics.setdefault(key,{})
    for sub,amount in value.items():nested[sub]=nested.get(sub,0)+amount
   else:metrics[key]=metrics.get(key,0)+value
  scenes+=1;print('PASS archive',folder.name,flush=True)
 assert scenes==require_scene_inventory(configurations)
 human=json.loads((OUT/'review.json').read_text())['human']['status']
 print('PASS portable'+str(scenes)+'sceneaudit',total,metrics,images,'realimages; humanstatus='+human)
if __name__=='__main__':main()
