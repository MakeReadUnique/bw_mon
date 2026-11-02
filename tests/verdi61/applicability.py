#!/usr/bin/env python3
import argparse
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description='Prove applicability of accepted views against fresh product FSDBs; never grants human approval.')
parser.add_argument('--source-root',type=Path,default=ROOT)
parser.add_argument('--acceptance',type=Path,required=True,help='fresh, independently verified steady_ns scene directory')
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
SOURCE=args.source_root.resolve()
OUT=args.output.resolve()
sys.path.insert(0,str(ROOT/'tests/verdi61'))
from compare import canonical_trace

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def run(command,cwd,log):
    start=time.monotonic()
    with log.open('w') as stream:
        p=subprocess.run([str(v) for v in command],cwd=str(cwd),stdout=stream,stderr=subprocess.STDOUT)
    receipt=dict(command=[str(v) for v in command],cwd=str(cwd),exit_code=p.returncode,elapsed_seconds=time.monotonic()-start)
    assert p.returncode==0,(receipt,log)
    return receipt

OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'applicability.json').exists():raise ValueError('Completed applicability output is immutable; choose a new output directory')
review=json.loads((ROOT/'evidence/verdi61/review.json').read_text())
fresh=OUT.parent/(OUT.name+'-fresh-runs')
prepare=run(['python3','tests/verdi61/prepare.py','--output',fresh],SOURCE,OUT/'prepare.log')
current={'steady_ns':args.acceptance.resolve(),'constant':fresh/'constant','alternating':fresh/'alternating'}
assert all((p/'waves.fsdb').exists() for p in current.values())
steady=json.loads((current['steady_ns']/'comparison.json').read_text())
assert steady['status']=='PASS'
configuration=json.loads((current['steady_ns']/'commands.json').read_text())['configuration']
assert configuration['scene']=='steady' and configuration['basis']=='ns'
archive=subprocess.check_output(['git','archive',review['asset_commit'],'artifacts/verdi61-data'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
    assets={m.name:bundle.extractfile(m).read() for m in bundle.getmembers() if m.isfile()}
converter=Path(shutil.which('fsdb2vcd')).resolve()
exports={};scene_runs={};files={}
for scene,source in current.items():
    scopes=sorted({signal.rsplit('/',1)[0] for view in review['views'] if view['scene']==scene for signal in view['expected_values']})
    folder=OUT/scene;folder.mkdir(exist_ok=True)
    old_fsdb=folder/'accepted.fsdb'
    original='artifacts/verdi61-data/'+scene+'/'
    old_fsdb.write_bytes(assets[original+'waves.fsdb'])
    copied={}
    for name in sorted(p.name for p in source.iterdir() if p.is_file()):
        if (source/name).exists():
            target=folder/name;shutil.copyfile(str(source/name),str(target));copied[name]=str(target.relative_to(OUT))
    old_checks=[l for l in assets[original+'run.log'].decode().splitlines() if l.startswith('BW_DEFAULT_CHECK ')]
    new_checks=[l for l in (source/'run.log').read_text().splitlines() if l.startswith('BW_DEFAULT_CHECK ')]
    assert old_checks==new_checks,(scene,'default results changed')
    old_source={};new_source={}
    for raw,destination in [(assets[original+'source.tar.gz'],old_source),((source/'source.tar.gz').read_bytes(),new_source)]:
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as snapshot:
            for item in snapshot.getmembers():
                if item.isfile() and item.name.startswith('rtl/'):
                    destination[item.name]=hashlib.sha256(snapshot.extractfile(item).read()).hexdigest()
    actual={n:sha(ROOT/n) for n in new_source}
    assert new_source==actual,(scene,'actual compiled RTL differs from current')
    commands=json.loads((source/'commands.json').read_text())
    project=commands['runtime_evidence']['compile_fingerprint']['project_sha256']
    assert set(project)<=set(review['source_sha256'])
    assert all(sha(ROOT/name)==digest for name,digest in project.items()),scene
    changed={n:dict(original=old_source[n],current=actual[n]) for n in actual if old_source[n]!=actual[n]}
    assert set(changed)=={'rtl/bw_default_check.svh'},changed
    scene_runs[scene]=dict(files=copied,old_fsdb_sha256=sha(old_fsdb),new_fsdb_sha256=sha(source/'waves.fsdb'),
                           compiled_rtl_sha256=new_source,source_changes=changed,identical_default_check_rows=len(new_checks))
    exports[scene]={}
    for role,fsdb in [('accepted',old_fsdb),('current',folder/'waves.fsdb')]:
        exports[scene][role]={}
        for i,scope in enumerate(scopes):
            vcd=folder/(role+'-'+str(i)+'.vcd')
            log=folder/(role+'-'+str(i)+'.export.log')
            command=[converter,fsdb,'-o',vcd,'-sv','-seq','-keep_last_time','-s',scope,'-level','1']
            receipt=run(command,folder,log)
            receipt.update(fsdb_sha256=sha(fsdb),vcd=str(vcd.relative_to(OUT)),vcd_sha256=sha(vcd))
            exports[scene][role][scope]=receipt
views=[]
for view in review['views']:
    begin,end=[int(Decimal(str(n))*1000000) for n in view['range_ns']]
    scopes=sorted({p.rsplit('/',1)[0] for p in view['expected_values']})
    traces={}
    for role in ['accepted','current']:
        trace={}
        for scope in scopes:
            paths=[p for p in view['expected_values'] if p.rsplit('/',1)[0]==scope]
            vcd=OUT/exports[view['scene']][role][scope]['vcd']
            trace.update(canonical_trace(vcd.read_text(),paths,begin,end))
        traces[role]=trace
    assert traces['accepted']==traces['current'],view['name']
    digest=hashlib.sha256(json.dumps(traces['current'],sort_keys=True,separators=(',',':')).encode()).hexdigest()
    views.append(dict(name=view['name'],scene=view['scene'],range_fs=[begin,end],signals=sorted(view['expected_values']),
                      accepted_image_sha256=view['image_sha256'],accepted_fsdb_sha256=view['fsdb_sha256'],
                      identical_trace_sha256=digest,unchanged=True))
for path in OUT.rglob('*'):
    if path.is_file():files[str(path.relative_to(OUT))]=sha(path)
proof=dict(schema='bw-verdi-source-applicability-v1',state='VERIFIED',
           source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=SOURCE,universal_newlines=True).strip(),
           accepted_asset_commit=review['asset_commit'],accepted_runtime_base=review['runtime_base'],
           converter=dict(path=str(converter),sha256=sha(converter)),prepare=prepare,
           verification_tool_sha256={str(p.relative_to(ROOT)):sha(p) for p in
               [Path(__file__).resolve(),ROOT/'tests/verdi61/compare.py',ROOT/'tests/verdi61/verify.py']},
           original_source_sha256=review['source_sha256'],current_source_sha256={n:sha(ROOT/n) for n in review['source_sha256']},
           scene_runs=scene_runs,exports=exports,views=views,files_sha256=files,
           note='Original accepted images/FSDBs and feedback remain unchanged. Native sequential exports cover each whole FSDB; selected ordered signal changes over each reviewed interval and final default-check rows match freshly compiled product source exactly. No unselected signal or other interval is certified.')
save(OUT/'applicability.json',proof)
print('PASS complete, exact waveform applicability:',len(views),'views',flush=True)
