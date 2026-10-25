#!/usr/bin/env python3
"""Archive original evidence; not a simulation/reference dependency."""
from pathlib import Path
import gzip,hashlib,json,sys
repo=Path(sys.argv[1]).resolve();manifest=Path(sys.argv[2]).resolve()
m=json.loads(manifest.read_text());attempt=manifest.parent
if m['state']!='VERIFIED':raise SystemExit('only completed verified profiles may be packaged')
destination=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else repo/'tests/scale/evidence'
out=destination/m['scenario'];out.mkdir(parents=True,exist_ok=True)
items={n:attempt/n for n in ['input.json','expect.cfg','expected.csv','actual.csv','diffs.json','verification.json','manifest.json','simulation.log','simulation.time-v.txt','input_pkg.sv','checker.sv','tb_bw_scale.sv']}
if (attempt/'supplementary-audit.json').exists():items['supplementary-audit.json']=attempt/'supplementary-audit.json'
items['compile.log']=Path(m['compile']['log']);items['compile.time-v.txt']=Path(m['compile']['time_v'])
native_dependency=Path(m['compile']['cwd'])/'csrc/bw_slot_settlement.d'
if native_dependency.exists():items['native-dependencies.d']=native_dependency
compile_cache=Path(m['compile']['cwd'])/'compile-success.json'
if compile_cache.exists():items['compile-success.json']=compile_cache
record=dict(scenario=m['scenario'],source_head=m['source_head'],source_tree=m['source_tree'],original_manifest=str(manifest),original_checked_pass=m['checked_pass'],files={})
for name,path in items.items():
 raw=path.read_bytes();compressed=out/(name+'.gz')
 with compressed.open('wb') as f:
  with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0,compresslevel=9) as z:z.write(raw)
 record['files'][name]=dict(original_path=str(path),uncompressed_bytes=len(raw),uncompressed_sha256=hashlib.sha256(raw).hexdigest(),gzip_file=compressed.name,gzip_bytes=compressed.stat().st_size,gzip_sha256=hashlib.sha256(compressed.read_bytes()).hexdigest())
(out/'bundle.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
print(m['scenario'],'packaged',sum(f['gzip_bytes'] for f in record['files'].values()),'compressed bytes;',m['verification']['checked_raw'],'raw checks;',m['verification']['checked_windows'],'windows')
