#!/usr/bin/env python3
"""Recheck portable acceptance archives and genuine assets without simulation."""
import hashlib,json,subprocess,tarfile,tempfile
from pathlib import Path
from model import configuration
from analysis import verify,verify_reports
from run import check_trace
from evidence import runtime_evidence,scene_runtime_evidence
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/acceptance'
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 inventory=json.loads((OUT/'SHA256SUMS.json').read_text())
 for name,digest in inventory.items():assert sha((OUT/name).read_bytes())==digest,('asset hash',name)
 runtime=runtime_evidence(ROOT,OUT)
 assert sha((OUT/'component-proof/final-408-proof.tar.gz').read_bytes())=='4eb443a37683d7be6dc669caab4121089a13cd5b751a2da9855434042b6cc6e7'
 total={};metrics={};images=0;scenes=0
 for folder in sorted(OUT.iterdir()):
  if not (folder/'commands.json').exists():continue
  m=json.loads((folder/'commands.json').read_text());c=m['configuration'];assert c==configuration(c['scene'],c['basis'])
  scene_runtime_evidence(ROOT,OUT,folder,m,runtime)
  with tempfile.TemporaryDirectory(prefix='acceptance-audit-') as name:
   work=Path(name)
   with tarfile.open(str(folder/'trace.tar.gz')) as archive:
    for member in archive.getmembers():
     assert member.isfile() and Path(member.name).name==member.name,'unexpected archive path'
     (work/member.name).write_bytes(archive.extractfile(member).read())
   rows=[[int(x) for x in line.split()] for line in (work/'stimulus.txt').read_text().splitlines()]
   basic=check_trace(c,work,rows);from model import frame_table,window_table
   frames=frame_table(rows);windows=window_table(c,rows,frames);log=(work/'run.log').read_text()
   assert 'TB_PASS acceptance' in log and 'Fatal:' not in log and 'Error-[' not in log and 'BW_CFG WARNING' not in log
   assert 'Warning-[' not in (work/'compile.log').read_text() and 'Error-[' not in (work/'compile.log').read_text()
   result=verify(c,rows,frames,windows,log);report=verify_reports(c,rows,frames,windows,log,(folder/'expect.cfg').read_text())
   recorded=json.loads((folder/'comparison.json').read_text());assert result==recorded['analysis_counts'] and report==recorded['report_reference'] and basic['counts']==recorded['counts']
   for path,digest in m['dependency_sha256'].items():
    target=ROOT/path
    data=target.read_bytes() if target.exists() else (work/'stimulus.txt').read_bytes() if path.endswith('/stimulus.txt') else None
    assert data is not None and sha(data)==digest,('source/input/cfg hash',folder,path)
  assert json.loads((folder/'resolved-signals.json').read_text())['status']=='PASS'
  for picture in folder.glob('*.png'):
   meta=folder/('capture-'+picture.stem+'-manifest.json')
   if not meta.exists():continue
   x=json.loads(meta.read_text());assert x['fresh'] and x['pixels']==[1500,850] and x['png_sha256']==sha(picture.read_bytes()) and x['fsdb_sha256']==sha((folder/'waves.fsdb').read_bytes());images+=1
  for key,value in basic['counts'].items():total[key]=total.get(key,0)+value
  for key,value in result.items():metrics[key]=metrics.get(key,0)+value
  scenes+=1;print('PASS archive',folder.name,flush=True)
 assert scenes==42
 human=json.loads((OUT/'review.json').read_text())['human']['status']
 print('PASS portable42sceneaudit',total,metrics,images,'realimages; humanstatus='+human)
if __name__=='__main__':main()
