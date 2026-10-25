#!/usr/bin/env python3
"""Supplementary source/compile/final-phase audit of recorded29 evidence only.
The accepted harness itself is in repo; this audit is not a simulation dependency.
Expected constant-flow phase boundary120/confirm150 comes from N3/K4/W100/S10.
"""
import csv,hashlib,json,re,sys
from pathlib import Path

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def kv(line):return dict(re.findall(r'(\w+)=([^\s]+)',line))
repo=Path(sys.argv[1]).resolve()
manifest_path=Path(sys.argv[2]).resolve()
m=json.loads(manifest_path.read_text());attempt=manifest_path.parent;errors=[]
build=Path(m['compile']['cwd'])
consumed=Path(m.get('source_snapshot',str(build)))
for name,expected in m['source_sha256'].items():
    if digest(repo/name)!=expected:errors.append(dict(error='current_source_hash',file=name))
    if name.startswith('rtl/') and digest(consumed/name)!=expected:errors.append(dict(error='build_snapshot_hash',file=name))
for name,expected in m['generated_sha256'].items():
    if digest(attempt/name)!=expected or digest(build/name)!=expected:errors.append(dict(error='generated_hash',file=name))
compile_log=Path(m['compile']['log']).read_text()
if m['compile']['returncode'] or re.search(r'(?:Warning|Error)-\[',compile_log):errors.append(dict(error='compile_diagnostic'))
if m['state']!='VERIFIED':errors.append(dict(error='not_verified_yet',state=m['state']))
if m.get('state')=='VERIFIED':
    if (attempt/'simulation.log').stat().st_mtime < Path(m['compile']['log']).stat().st_mtime:errors.append(dict(error='runtime_precedes_compile'))
    for name,h in m['evidence_sha256'].items():
        if digest(attempt/name)!=h:errors.append(dict(error='evidence_hash',file=name))
    lines=(attempt/'simulation.log').read_text().splitlines()
    if len([l for l in lines if l.startswith('BW_READY ')])!=1:errors.append(dict(error='ready_count'))
    baseline=m['configuration']['config']['variant']=='baseline'
    phases={kv(l)['scope']:kv(l) for l in lines if l.startswith('BW_PHASE ')}
    steady={kv(l)['scope']:kv(l) for l in lines if l.startswith('BW_LAST_STEADY ')}
    rows=list(csv.DictReader((attempt/'expected.csv').open()))
    if baseline:
        cycle=m['configuration']['config']['basis']=='cycle';offset=250000 if cycle else 0
        for r in rows:
            sid=r['scope'];card=int(r['cardinality']);phase=phases.get(sid,{})
            expected=dict(kind=2,epoch=0,episode=1,phase=1,result_seq=1,start_ticks=120000000+offset,
                          confirm_ticks=150000000+offset,end_ticks=m['configuration']['end_ticks'],start_known=1,end_known=0,
                          start_bytes=15360*card,start_events=240*card,end_bytes=5120000*card,end_events=80000*card,reason=2)
            # Smoke duration is also permitted and has the same candidate/confirmation.
            edges=m['configuration']['expected_edges'];expected['end_bytes']=64*edges*card;expected['end_events']=edges*card
            for field,value in expected.items():
                if phase.get(field)!=str(value):errors.append(dict(error='constant_phase',scope=sid,field=field,expected=value,actual=phase.get(field)))
            for field in ('delta','rms'):
                if phase.get(field) is None or abs(float(phase[field]))>1e-10:errors.append(dict(error='constant_fit',scope=sid,field=field))
            selected=steady.get(sid,{})
            for field,value in dict(found=1,selection_valid=0,phase=1,phase_result_seq=1,bandwidth_valid=0).items():
                if selected.get(field)!=str(value):errors.append(dict(error='constant_last_steady',scope=sid,field=field))
    result=dict(manifest=str(manifest_path),audit_script_sha256=digest(Path(__file__)),source_hashes=len(m['source_sha256']),generated_hashes=len(m['generated_sha256']),
                checked_scopes=len(rows),constant_phase_check=baseline,differences=errors)
else:result=dict(manifest=str(manifest_path),differences=errors)
(attempt/'supplementary-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='differences'}));print('audit_differences='+str(len(errors)))
sys.exit(bool(errors))
