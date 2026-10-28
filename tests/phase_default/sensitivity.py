#!/usr/bin/env python3
"""Offline sensitivity at the public log seam; never changes saved input logs.

Copies the four saved families, then makes isolated one-femtosecond or quality
mutations. A candidate verifier must accept the originals and reject every
mutation. These synthetic negative logs are not product evidence.
"""
import argparse
import contextlib
import io
import json
from pathlib import Path
import re

from check import check, fields, TICKS

FAMILIES=('continuous','platforms','activity','recovery')


def replace_field(line,name,value):
    return re.sub(r'(?<!\w)'+re.escape(name)+r'=[^ ]+',name+'='+str(value),line,count=1)


def entries(lines,prefix,case,kind):
    current=None
    for index,line in enumerate(lines):
        v=fields(line)
        if line.startswith('FIXED_CASE '):current=int(v['case'])
        if current!=case or not line.startswith(prefix):continue
        if prefix=='BW_PHASE ':
            if not v.get('scope','').startswith('phase.fixed.'+kind):continue
        elif v.get('kind')!=kind:continue
        yield index,v


def invoke(path,family):
    output=io.StringIO()
    try:
        with contextlib.redirect_stdout(output):result=check(path,family)
        return {'accepted':True,'result':result,'output':output.getvalue()}
    except AssertionError as error:
        return {'accepted':False,'diagnostic':str(error)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--only',choices=['phase','window','all'],default='all')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    originals={f:(args.logs/('phase_fixed_'+f+'.log')).read_text().splitlines() for f in FAMILIES}
    report={'source_logs':str(args.logs),'synthetic_mutations':True,'baselines':[],'mutations':[]}
    for family,lines in originals.items():
        path=args.output/(family+'-baseline.log');path.write_text('\n'.join(lines)+'\n')
        result=invoke(path,family);report['baselines'].append(dict(family=family,**result))
        if not result['accepted']:
            (args.output/'result.json').write_text(json.dumps(report,indent=2)+'\n')
            raise AssertionError((family,'unchanged baseline rejected',result))

    def mutation(family,label,index,changes):
        lines=list(originals[family]);line=lines[index]
        for field,value in changes.items():line=replace_field(line,field,value)
        lines[index]=line
        path=args.output/(label+'.log');path.write_text('\n'.join(lines)+'\n')
        result=invoke(path,family)
        report['mutations'].append(dict(name=label,family=family,changes=changes,**result))

    if args.only in ('phase','all'):
        contexts=[('continuous',1,'first',lambda candidates:candidates[0]),
                  ('continuous',1,'tail',lambda candidates:candidates[-1]),
                  ('platforms',3,'cycle',lambda candidates:candidates[0]),
                  ('recovery',11,'reset',lambda candidates:next(x for x in candidates if x[1]['end_known']=='0')),
                  ('recovery',11,'recovered',lambda candidates:next(x for x in candidates if x[1]['epoch']=='1'))]
        for family,case,label,select in contexts:
            for kind in ('point','group'):
                index,v=select(list(entries(originals[family],'BW_PHASE ',case,kind)))
                for field in ('start_ticks','confirm_ticks','end_ticks'):
                    mutation(family,'{}-{}-{}-{}-plus-1fs'.format(family,label,kind,field),index,{field:int(v[field])+1})
    if args.only in ('window','all'):
        contexts=[('continuous',1,'ns',lambda v:True),
                  ('platforms',3,'cycle',lambda v:v['full']=='1'),
                  ('activity',6,'warmup',lambda v:v['full']=='0'),
                  ('activity',9,'no-episode',lambda v:v['full']=='1'),
                  ('recovery',11,'gap',lambda v:v['complete']=='0'),
                  ('recovery',11,'reset-warmup',lambda v:v['full']=='0' and int(v['ticks'])>172*TICKS)]
        for family,case,label,predicate in contexts:
            for kind in ('point','group'):
                index,v=next(x for x in entries(originals[family],'FIXED_WINDOW ',case,kind) if predicate(x[1]))
                for field in ('left','ticks'):
                    mutation(family,'{}-{}-{}-{}-plus-1fs'.format(family,label,kind,field),index,{field:int(v[field])+1})
                for field in ('full','complete','eligible'):
                    mutation(family,'{}-{}-{}-flip-{}'.format(family,label,kind,field),index,{field:1-int(v[field])})
        for kind in ('point','group'):
            index,v=next(entries(originals['continuous'],'FIXED_WINDOW ',1,kind))
            left=int(v['left'])+1
            mutation('continuous','continuous-{}-coherent-wrong-left'.format(kind),index,
                     {'left':left,'full':0,'y':int(v['bytes'])*TICKS/(int(v['ticks'])-left)})
            index,v=list(entries(originals['continuous'],'FIXED_WINDOW ',1,kind))[1]
            left=int(v['left'])+1
            mutation('continuous','continuous-{}-coherent-nontarget-left'.format(kind),index,
                     {'left':left,'full':0,'eligible':0,'y':int(v['bytes'])*TICKS/(int(v['ticks'])-left)})
    accepted=[m['name'] for m in report['mutations'] if m['accepted']]
    report['passed']=not accepted
    report['accepted_mutations']=accepted
    report['mutations_checked']=len(report['mutations'])
    (args.output/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ORACLE_SENSITIVITY {} baselines={} rejected={}/{}'.format('PASS' if report['passed'] else 'FAIL',len(report['baselines']),len(report['mutations'])-len(accepted),len(report['mutations'])))
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
