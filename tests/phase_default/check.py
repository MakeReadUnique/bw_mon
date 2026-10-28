#!/usr/bin/env python3
"""Verify the fixed R2 scenarios using raw protocol inputs and approved targets.

Window bytes/quality come from an independent half-open interval sum, never
product history. Phase expectations are frozen accepted R2 behavior, not labels
inferred from this product run. This checker makes no 5% performance claims.
"""
import json
from pathlib import Path
import re
import sys

TICKS = 1_000_000
HERE = Path(__file__).resolve().parent

def fields(line):
    return dict(re.findall(r'(\w+)=([^ ]+)', line))

def check(log_path, family_id):
    family = next(f for f in json.loads((HERE/'fixed.json').read_text())['families'] if f['id']==family_id)
    cases = {c['id']:c for c in family['cases']}
    origins, windows, phases, enum = {}, {}, {}, {}
    current = None
    for line in Path(log_path).read_text().splitlines():
        v = fields(line)
        if line.startswith('FIXED_ENUM '): enum = {value:key for key,value in v.items()}
        elif line.startswith('FIXED_CASE '):
            current=int(v['case']);origins[current]=int(v['origin'])
        elif line.startswith('FIXED_WINDOW '):
            windows.setdefault((int(v['case']),v['kind']),[]).append(v)
        elif line.startswith('BW_PHASE ') and v.get('scope','').startswith('phase.fixed.'):
            scope=v['scope'].split('.')[-1]
            if scope.startswith(('point','group')):
                kind='point' if scope.startswith('point') else 'group'
                phases.setdefault((current,kind),[]).append(v)
    assert set(origins)==set(cases), ('missing input cases',set(cases)-set(origins))
    count=0;targets=[]
    for cid,c in cases.items():
        origin=origins[cid]
        activity=[(origin+(r['u']-1)*TICKS+1,r) for r in c['rows']]
        for kind in ('point','group'):
            observed=windows.get((cid,kind),[])
            assert observed, (cid,kind,'no published windows')
            unique=set()
            for v in observed:
                end,left=int(v['ticks']),int(v['left'])
                assert end not in unique, (cid,kind,'duplicate window',end)
                unique.add(end)
                raw=[r for tick,r in activity if left<=tick<end]
                expected_bytes=sum(sum(r['members']) for r in raw if r['events'] and r['known'] and not r['reset'])
                expected_complete=all(r['known'] for r in raw if not r['reset'])
                assert int(v['bytes'])==expected_bytes, (cid,kind,end,'bytes',v['bytes'],expected_bytes)
                assert bool(int(v['complete']))==expected_complete,(cid,kind,end,'quality',v['complete'],expected_complete)
                assert abs(float(v['y'])-expected_bytes*TICKS/(end-left))<=1e-9,(cid,kind,end,'bandwidth')
                count+=1
            actual=[]
            for p in phases.get((cid,kind),[]):
                actual.append({'label':enum[p['kind']],**{out:(int(p[at])-origin)//TICKS for out,at in
                    [('start','start_ticks'),('confirm','confirm_ticks'),('end','end_ticks')]}})
            assert actual==c['phases'],(cid,kind,'phase timeline',actual,c['phases'])
            for target in c['targets']:
                p=next(p for p in phases[(cid,kind)] if enum[p['kind']]==target['label'] and
                       (int(p['start_ticks'])-origin)//TICKS==target['boundary'])
                first=next(v for v in observed if (int(v['ticks'])-origin)//TICKS==target['first'])
                confirm=int(p['confirm_ticks']);first_tick=int(first['ticks'])
                updates=1+(target['confirmation']-target['first'])//family['s']
                assert int(first['eligible'])==1 and 1<=updates<=8,(cid,kind,target['key'],'deadline')
                assert confirm<=origin+target['deadline']*TICKS+1,(cid,kind,target['key'],'physical deadline')
                targets.append({'case':cid,'kind':kind,'target':target['key'],'first_ticks':first_tick,
                    'boundary_ticks':int(p['start_ticks']),'confirmation_ticks':confirm,'updates':updates,
                    'seven_stride_ticks':7*family['s']*TICKS,'first_to_confirmation_ticks':confirm-first_tick,
                    'input_to_confirmation_ticks':confirm-(origin+target['inputU']*TICKS+1)})
    result={'family':family_id,'windows_checked':count,'targets_checked':len(targets),'targets':targets,
            'wrong_confirmations':0,'extra_switches':0,'checker_claim':False}
    Path(log_path).with_suffix('.verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f"PHASE_FIXED_PASS family={family_id} windows={count} targets={len(targets)} wrong=0 extra=0")
    return result

if __name__=='__main__':
    check(sys.argv[1],sys.argv[2])
