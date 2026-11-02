#!/usr/bin/env python3
"""Replay final contract, default-campaign and public-scene evidence without VCS."""
import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def require(value,reason):
    if not value:raise ValueError(reason)
def read(path):
    return (gzip.decompress(path.read_bytes()) if path.suffix=='.gz' else path.read_bytes()).decode()


def case_inventory(cases,output):
    rows=re.findall(r'^(PASS|FAIL) ([A-Za-z0-9_]+):',output,re.M)
    expected=[case['name'] for case in cases]
    require([name for state,name in rows]==expected and all(state=='PASS' for state,name in rows),
            'missing, duplicate, reordered, failed or extra contract case')
    require(re.search(r'^%d/%d contract cases passed$'%(len(cases),len(cases)),output,re.M),
            'full contract completion is absent')
    return expected


def contract_fingerprint(source,original_root,case):
    rtl=source/'rtl'
    files=sorted(rtl.glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))+sorted(rtl.glob('*.c'))
    files += [source/'tests'/name for name in case.get('sources',[])]+[source/'tests'/(case['top']+'.sv')]
    files += sorted(path for path in rtl.rglob('*') if path.suffix in {'.svh','.vh','.h'})
    digest=hashlib.sha256(str(original_root).encode()+(source/'tests/run.py').read_bytes()+
                          json.dumps(case.get('defines',[])).encode())
    for path in files:
        digest.update(str(Path(original_root)/path.relative_to(source)).encode());digest.update(path.read_bytes())
    return digest.hexdigest()


def verify_contracts(directory,source,receipt):
    cases=json.loads((source/'tests/cases.json').read_text())
    record=receipt['contracts']
    require(record['exit_code']==0,'contract process did not complete')
    case_inventory(cases,read(directory/record['output']))
    require(set(record['cases'])=={case['name'] for case in cases},'contract log inventory differs')
    campaign_path=directory/record['campaign'];campaign=json.loads(campaign_path.read_text())
    require(campaign['checked_pass'] and campaign['source_unchanged'] and campaign['cold'] and
            campaign['source_head']==receipt['source_head'],'contract campaign source or completion differs')
    seen=set();top_owner={}
    for n,job in enumerate(campaign['jobs']):
        require(job['exit_code']==0,'contract shard failed')
        selected=[case for case in cases if case['name'] in set(job['cases'])]
        require(not (seen & set(job['cases'])),'contract case repeated in shards')
        case_inventory(selected,read(campaign_path.parent/job['output']))
        for case in selected:
            require(case['top'] not in top_owner or top_owner[case['top']]==n,'test top shared by parallel shards')
            top_owner[case['top']]=n
        seen.update(job['cases'])
    require(seen=={case['name'] for case in cases},'contract shard inventory incomplete')
    with tempfile.TemporaryDirectory(prefix='bw-contract-replay-') as temporary:
        for case in cases:
            entry=record['cases'][case['name']]
            compile_text=read(directory/entry['compile_log'])
            if case.get('expect_compile_error'):
                require(re.search(case['expect_compile_error'],compile_text),'native compile rejection missing: '+case['name'])
                continue
            expected=contract_fingerprint(source,record['source_root'],case)
            require(entry['build_digest']==expected and read(directory/entry['source_stamp']).strip()==expected,
                    'contract consumed another source or macro variant: '+case['name'])
            text=read(directory/entry['log'])
            if case.get('expect_error'):
                require('Fatal:' in text and re.search(case['expect_error'],text) and 'TB_PASS' not in text,
                        'expected runtime error missing: '+case['name'])
            else:
                require('TB_PASS' in text and 'Fatal:' not in text,'contract failed: '+case['name'])
                if case.get('expect_warning'):require(re.search(case['expect_warning'],text),'expected warning missing')
            require(all(re.search(pattern,text) for pattern in case.get('expect_log',[])),'contract record missing')
            require(all(len(re.findall(pattern,text))==count for pattern,count in case.get('expect_counts',{}).items()),
                    'contract record count differs')
            if case.get('verify'):
                log=Path(temporary)/(case['name']+'.log');log.write_text(text)
                command=[str(source/item) if item.startswith('tests/') else str(log) if item=='{log}' else item
                         for item in case['verify']]
                subprocess.check_call(command,cwd=source,stdout=subprocess.DEVNULL)
    return len(cases)


CAMPAIGN_REPLAY=r'''
import json,sys,tempfile
from pathlib import Path
source=Path(sys.argv[1]);directory=Path(sys.argv[2]);sys.path.insert(0,str(source/'tests/campaign58'))
import aspects,joint,run
r=json.loads((directory/'timing.json').read_text())
assert r['source']==sys.argv[3]
assert r['passed'] and r['completed'] and r['cold'] and not r['dirty_source']
assert r['budget_seconds']==900 and run.within_budget(r)
assert abs(run.campaign_total_seconds(r)-r['total_seconds'])<1e-6
assert run.stage_summary(r['commands'])==r['stage_seconds']
assert all(c['returncode']==0 for c in r['commands'])
assert r['cases']==aspects.campaign_cases() and set(r['case_outcomes'])==set(r['cases'])
assert all(r['case_outcomes'].values()) and r['control_table_verified'] and not r['table_differences']
tables=[]
with tempfile.TemporaryDirectory(prefix='bw-joint-replay-') as temporary:
 for family in aspects.FIXED_ALLOCATION:
  path=Path(temporary)/(family['case']+'.log')
  path.write_bytes((directory/(family['case']+'.log')).read_bytes())
  checker=joint.run_ownership_checker(path,family['id'])
  tables.append(joint.build_family_table(family['id'],path,path.with_suffix('.verification.json'),checker))
assert tables==r['joint_tables']==json.loads((directory/'joint-table.json').read_text())
for family in aspects.FIXED_ALLOCATION:
 assert run.sha256_file(source/'tests/phase_default'/(family['id']+'.txt'))==r['fixed_inputs'][family['id']]
assert run.sha256_file(source/'tests/phase_default/fixed.json')==r['fixed_configuration']
print('PASS frozen four-input campaign, 54 targets, exact references and 900s budget')
'''

ACCEPTANCE_REPLAY=r'''
import hashlib,json,sys
from pathlib import Path
source=Path(sys.argv[1]);directory=Path(sys.argv[2]);sys.path.insert(0,str(source/'tests/acceptance'))
import model
from audit import replay_recorded_reference
from evidence import project_sources,scene_runtime_evidence,runtime_sources
configurations=[];totals={}
for folder in sorted(directory.iterdir()):
 if not (folder/'commands.json').exists():continue
 m=json.loads((folder/'commands.json').read_text());c=m['configuration'];configurations.append(c)
 assert c['N']==6
 native=scene_runtime_evidence(source,directory,folder,m,{})
 assert native['head']==sys.argv[3]
 assert native['rtl_sha256']==runtime_sources(source)
 project=project_sources(directory,folder,m)
 assert all((source/name).is_file() and hashlib.sha256((source/name).read_bytes()).hexdigest()==hashlib.sha256(data).hexdigest()
            for name,data in project.items())
 rows=[[int(v) for v in line.split()] for line in (folder/'stimulus.txt').read_text().splitlines()]
 assert rows==model.stimulus(model.configuration(c['scene'],c['basis']))
 for name,digest in m['dependency_sha256'].items():
  if name.startswith(('rtl/','tests/')):data=project_sources(directory,folder,m)[name]
  else:data=(folder/Path(name).name).read_bytes()
  assert hashlib.sha256(data).hexdigest()==digest
 replay=replay_recorded_reference(project_sources(directory,folder,m),m,folder)
 saved=json.loads((folder/'comparison.json').read_text())
 assert saved['status']=='PASS'
 assert replay['basic']['counts']==saved['counts']
 assert replay['analysis']==saved['analysis_counts'] and replay['report']==saved['report_reference']
 for key,value in saved['counts'].items():totals[key]=totals.get(key,0)+value
assert len(configurations)==model.require_scene_inventory(configurations)==43
print('PASS 43 new-source scenes:',totals)
'''


def verify_execution(rows):
    expected={'quick-cold','quick-hot','full-cold','full-hot','campaign58','acceptance',
              'bw_mon_quickstart-compile','bw_mon_quickstart','bw_mon_grouped-compile',
              'bw_mon_grouped','verdi-applicability','python-tools','contracts-final'}
    require(len(rows)==len(expected) and {row['name'] for row in rows}==expected,
            'delivery execution missing, duplicate or unexpected job')
    budgets={'quick-cold':300,'quick-hot':120,'full-cold':1800,'full-hot':1800,'campaign58':900}
    for row in rows:
        require(row['exit_code']==0,'delivery job failed: '+row['name'])
        elapsed=row['elapsed_seconds']
        require(isinstance(elapsed,(int,float)) and not isinstance(elapsed,bool) and
                math.isfinite(elapsed) and elapsed>=0,'invalid outer elapsed time')
        if row['name'] in budgets:
            budget=budgets[row['name']]
            require(row.get('budget_seconds')==budget and row.get('budget_met') is True and elapsed<=budget,
                    'outer command budget failed: '+row['name'])


def verify(directory):
    receipt=json.loads((directory/'run-evidence.json').read_text())
    require(receipt['schema']=='bw-spec48-run-evidence-v1' and receipt['state']=='VERIFIED','delivery incomplete')
    verify_execution(receipt['execution'])
    for relative,digest in receipt['files_sha256'].items():
        path=Path(relative)
        require(not path.is_absolute() and '..' not in path.parts,'unsafe proof path')
        require(sha(directory/path)==digest,'proof file changed: '+relative)
    require(json.loads((directory/'execution/results.json').read_text())==receipt['execution'],
            'execution summary differs from original controller record')
    source=directory/'source'
    count=verify_contracts(directory,source,receipt)
    for code,folder in [(CAMPAIGN_REPLAY,'campaign58'),(ACCEPTANCE_REPLAY,'acceptance')]:
        subprocess.check_call([sys.executable,'-B','-c',code,str(source),str(directory/folder),receipt['source_head']])
    return dict(checked_pass=True,contract_cases=count,public_scenes=43)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    args=parser.parse_args();print(json.dumps(verify(args.directory.resolve()),sort_keys=True))
