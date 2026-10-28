#!/usr/bin/env python3
"""Verify the fixed R2 scenarios using raw protocol inputs and approved targets.

Window bytes/quality come from an independent half-open interval sum, never
product history. Phase expectations are frozen accepted R2 behavior, not labels
inferred from this product run. This checker makes no 5% performance claims.
"""
import json
import math
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
    metrics, variations = {}, {}
    current = None
    for line in Path(log_path).read_text().splitlines():
        v = fields(line)
        if line.startswith('FIXED_ENUM '): enum = {value:key for key,value in v.items()}
        elif line.startswith('FIXED_CASE '):
            current=int(v['case']);origins[current]=int(v['origin'])
        elif line.startswith('FIXED_WINDOW '):
            windows.setdefault((int(v['case']),v['kind']),[]).append(v)
        elif line.startswith(('BW_PHASE_METRICS ','BW_VARIATION ')) and v.get('scope','').startswith('phase.fixed.'):
            if line.startswith('BW_VARIATION ') and v.get('interval')!='PHASE':continue
            scope=v['scope'].split('.')[-1]
            if scope.startswith(('point','group')):
                kind='point' if scope.startswith('point') else 'group'
                target=metrics if line.startswith('BW_PHASE_METRICS ') else variations
                target[(current,kind,v['phase'])]=v
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
            if family['basis']=='cycle':
                expected_ticks={origin+u*TICKS+1 for u in range(family['s'],len(c['rows']),family['s'])}
            else:
                expected_ticks=set();epoch_start=origin;asserted=False
                reset_edges=[(at,bool(r['reset'])) for at,r in activity]
                next_tick=origin+family['s']*TICKS
                for at,reset in reset_edges+[(origin+len(c['rows'])*TICKS+(1 if cid==family['cases'][-1]['id'] else 0),False)]:
                    while not asserted and next_tick<at:
                        expected_ticks.add(next_tick);next_tick+=family['s']*TICKS
                    if asserted and not reset:
                        epoch_start=at;next_tick=at+family['s']*TICKS
                    asserted=reset
            assert {int(v['ticks']) for v in observed}==expected_ticks,(cid,kind,'publication schedule')
            unique=set()
            for v in observed:
                end,left=int(v['ticks']),int(v['left'])
                assert end not in unique, (cid,kind,'duplicate window',end)
                unique.add(end)
                raw=[r for tick,r in activity if left<=tick<end]
                expected_bytes=sum(sum(r['members']) for r in raw if r['events'] and r['known'] and not r['reset'])
                expected_complete=all(r['known'] for r in raw if not r['reset'])
                assert int(v['bytes'])==expected_bytes, (cid,kind,end,'bytes',v['bytes'],expected_bytes)
                assert bool(int(v['full']))==(end-left==family['w']*TICKS),(cid,kind,end,'full coverage')
                assert bool(int(v['complete']))==expected_complete,(cid,kind,end,'quality',v['complete'],expected_complete)
                assert abs(float(v['y'])-expected_bytes*TICKS/(end-left))<=1e-9,(cid,kind,end,'bandwidth')
                count+=1
            # Final phase bytes use raw events; variation equally weights the
            # eligible full windows in that final interval. The sources differ.
            for p in phases.get((cid,kind),[]):
                key=(cid,kind,p['phase']);m=metrics[key];v=variations[key]
                start,end=int(p['start_ticks']),int(p['end_ticks'])
                raw=[r for tick,r in activity if start<=tick<end]
                if int(m['events_complete']) and int(p['end_known']):
                    expected_events=sum(r['events'] for r in raw if not r['reset'])*(4 if kind=='group' else 1)
                    assert int(m['events'])==expected_events,(cid,kind,'phase events',m,expected_events)
                if int(m['bandwidth_valid']):
                    expected=sum(sum(r['members']) for r in raw if r['events'] and r['known'] and not r['reset'])
                    assert int(m['bytes'])==expected,(cid,kind,'phase raw bytes',m,expected)
                    assert abs(float(m['bandwidth_gbps'])-expected*TICKS/(end-start))<=1e-9,(cid,kind,'phase raw bandwidth')
                ys=[]
                for w in observed:
                    tick,left=int(w['ticks']),int(w['left'])
                    selected=[r for at,r in activity if left<=at<tick]
                    if start<=tick<end and tick-left==family['w']*TICKS and all(r['known'] for r in selected):
                        ys.append(sum(sum(r['members']) for r in selected if r['events'] and not r['reset'])*TICKS/(tick-left))
                assert int(v['samples'])==len(ys),(cid,kind,'phase window count',v,len(ys))
                if ys:
                    mean=sum(ys)/len(ys)
                    assert abs(float(v['mean_gbps'])-mean)<=1e-9,(cid,kind,'phase window mean')
                    assert float(v['min_gbps'])==min(ys) and float(v['max_gbps'])==max(ys),(cid,kind,'phase minmax')
                    if int(v['stddev_valid']):
                        sigma=math.sqrt(sum((y-mean)**2 for y in ys)/len(ys))
                        assert abs(float(v['stddev_gbps'])-sigma)<=1e-9,(cid,kind,'phase population sigma')
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
