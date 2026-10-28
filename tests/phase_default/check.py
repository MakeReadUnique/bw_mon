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

from window_reference import reference_family

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
    registrations=[]
    measurement_starts=[]
    for line in Path(log_path).read_text().splitlines():
        v = fields(line)
        if line.startswith('BW_READY '):
            registrations.append((int(v['points']),int(v['groups'])))
            measurement_starts.append(int(v['time_ticks']))
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
    assert registrations==[(5,1)], ('T4 requires exactly five registered points and one group',registrations)
    references=reference_family(family,measurement_starts[0])
    assert set(origins)==set(cases)==set(references), ('missing input cases',set(cases)-set(origins))
    assert origins=={cid:ref.origin for cid,ref in references.items()}, ('case origins',origins)
    count=0;targets=[]
    for cid,c in cases.items():
        reference=references[cid]
        origin=reference.origin
        activity=reference.activity
        publications={w.u:w for w in reference.windows}
        expected_phases=[]
        for phase in c['phases']:
            start=publications[phase['start']].ticks
            episode=next(e for e in reference.episodes if e.first_ticks<=start<e.end_ticks)
            # Frozen R2 boundaries are logical positions. Actual timestamps
            # come from the independent publication and raw episode models.
            # A final tail/reset can be 1fs after the NS result at the same u.
            end=(episode.end_ticks if phase['end']==episode.end_u else
                 publications[phase['end']].ticks)
            expected_phases.append({'label':phase['label'],'start':start,
                                    'confirm':publications[phase['confirm']].ticks,'end':end})
        for kind in ('point','group'):
            observed=windows.get((cid,kind),[])
            assert observed, (cid,kind,'no published windows')
            expected_windows=reference.windows
            assert [int(v['ticks']) for v in observed]==[w.ticks for w in expected_windows],(cid,kind,'publication schedule')
            for v,w in zip(observed,expected_windows):
                # No product interval or quality flag is used to construct the
                # oracle. Geometry, bytes and eligibility all originate in the
                # original protocol rows, actual edges and reset epochs.
                for field in ('left','bytes','full','complete','eligible'):
                    assert int(v[field])==getattr(w,field),(cid,kind,w.ticks,field,v[field],getattr(w,field))
                assert abs(float(v['y'])-w.y)<=1e-9,(cid,kind,w.ticks,'bandwidth',v['y'],w.y)
                count+=1
            actual=[{'label':enum[p['kind']],'start':int(p['start_ticks']),
                     'confirm':int(p['confirm_ticks']),'end':int(p['end_ticks'])}
                    for p in phases.get((cid,kind),[])]
            assert actual==expected_phases,(cid,kind,'exact phase ticks',actual,expected_phases)
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
                ys=[w.y for w in expected_windows if start<=w.ticks<end and w.eligible]
                assert int(v['samples'])==len(ys),(cid,kind,'phase window count',v,len(ys))
                if ys:
                    mean=sum(ys)/len(ys)
                    assert abs(float(v['mean_gbps'])-mean)<=1e-9,(cid,kind,'phase window mean')
                    assert float(v['min_gbps'])==min(ys) and float(v['max_gbps'])==max(ys),(cid,kind,'phase minmax')
                    if int(v['stddev_valid']):
                        sigma=math.sqrt(sum((y-mean)**2 for y in ys)/len(ys))
                        assert abs(float(v['stddev_gbps'])-sigma)<=1e-9,(cid,kind,'phase population sigma')
            for target in c['targets']:
                position=next(i for i,p in enumerate(c['phases'])
                              if p['label']==target['label'] and p['start']==target['boundary'])
                p=phases[(cid,kind)][position]
                first_tick=publications[target['first']].ticks
                first=next(v for v in observed if int(v['ticks'])==first_tick)
                confirm=int(p['confirm_ticks'])
                updates=1+(target['confirmation']-target['first'])//family['s']
                assert publications[target['first']].eligible and int(first['eligible'])==1 and 1<=updates<=8,(cid,kind,target['key'],'deadline')
                assert confirm==publications[target['confirmation']].ticks,(cid,kind,target['key'],'exact confirmation')
                assert confirm<=publications[target['deadline']].ticks,(cid,kind,target['key'],'physical deadline')
                targets.append({'case':cid,'kind':kind,'target':target['key'],'first_ticks':first_tick,
                    'boundary_ticks':int(p['start_ticks']),'confirmation_ticks':confirm,'updates':updates,
                    'seven_stride_ticks':7*family['s']*TICKS,'first_to_confirmation_ticks':confirm-first_tick,
                    'input_to_confirmation_ticks':confirm-(origin+target['inputU']*TICKS+1)})
    result={'family':family_id,'registered_points':5,'registered_groups':1,'windows_checked':count,'targets_checked':len(targets),'targets':targets,
            'wrong_confirmations':0,'extra_switches':0,'checker_claim':False,
            'time_comparison':'exact integer femtoseconds','window_oracle':'raw input clock/reset/episode model'}
    Path(log_path).with_suffix('.verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f"PHASE_FIXED_PASS family={family_id} windows={count} targets={len(targets)} wrong=0 extra=0")
    return result

if __name__=='__main__':
    check(sys.argv[1],sys.argv[2])
