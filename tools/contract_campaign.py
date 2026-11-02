#!/usr/bin/env python3
"""Run every contract once after timing qualification, with disjoint test tops."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from spec48_audit import case_inventory

ROOT=Path(__file__).resolve().parents[1]


def partition(cases,workers):
    tops={}
    for case in cases:tops.setdefault(case['top'],[]).append(case)
    groups=[[] for _ in range(workers)];weights=[0]*workers
    for top,rows in sorted(tops.items(),key=lambda item:(-len(item[1]),item[0])):
        index=min(range(workers),key=lambda n:weights[n])
        groups[index].extend(case['name'] for case in rows)
        weights[index]+=len(rows)+3*len({tuple(case.get('defines',[])) for case in rows})
    return [[case for case in cases if case['name'] in names] for names in map(set,groups)]


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    cases=json.loads((ROOT/'tests/cases.json').read_text());groups=partition(cases,min(3,os.cpu_count() or 1))
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,universal_newlines=True).strip()
    status=subprocess.check_output(['git','status','--porcelain'],cwd=ROOT)
    if status:raise ValueError('Contract campaign requires a clean fixed source')
    started=time.monotonic();jobs=[];record=[]
    for index,group in enumerate(groups):
        path=output/('shard-%d.log'%index);stream=path.open('w')
        command=[sys.executable,str(ROOT/'tests/run.py'),'--no-cache']+[case['name'] for case in group]
        process=subprocess.Popen(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        jobs.append((process,stream,path,group,command))
    observed={};okay=True
    for process,stream,path,group,command in jobs:
        code=process.wait();stream.close();text=path.read_text()
        entry=dict(command=command,exit_code=code,output=path.name,cases=[case['name'] for case in group])
        record.append(entry)
        if code:okay=False
        try:case_inventory(group,text)
        except ValueError:okay=False
        for line in text.splitlines():
            if line.startswith(('PASS ','FAIL ')) and ':' in line:
                name=line.split(':',1)[0].split(' ',1)[1]
                if name in observed:raise ValueError('Contract executed in multiple shards: '+name)
                observed[name]=line
    unchanged=(subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,universal_newlines=True).strip()==head and
               not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip())
    okay=okay and unchanged and set(observed)=={case['name'] for case in cases}
    report=dict(source_head=head,source_unchanged=unchanged,cold=True,workers=len(jobs),jobs=record,
                elapsed_seconds=time.monotonic()-started,checked_pass=okay)
    (output/'campaign.json').write_text(json.dumps(report,indent=2)+'\n')
    for case in cases:
        if case['name'] in observed:print(observed[case['name']],flush=True)
    passed=sum(line.startswith('PASS ') for line in observed.values())
    print('%d/%d contract cases passed'%(passed,len(cases)),flush=True)
    return 0 if okay else 1


if __name__=='__main__':raise SystemExit(main())
