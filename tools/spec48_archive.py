#!/usr/bin/env python3
"""Collect completed final runs, preserving raw logs and macro build receipts."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec48_audit import case_inventory,contract_fingerprint


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def pack(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    with target.open('wb') as raw:
        with gzip.GzipFile(filename='',fileobj=raw,mode='wb',mtime=0) as stream:stream.write(source.read_bytes())


def collect(source,runs,records,destination):
    if destination.exists():raise ValueError('Choose a new immutable archive destination')
    execution=json.loads((records/'results.json').read_text())
    expected={'quick-cold','quick-hot','full-cold','full-hot','campaign58','acceptance',
              'bw_mon_quickstart-compile','bw_mon_quickstart','bw_mon_grouped-compile','bw_mon_grouped',
              'verdi-applicability','python-tools','contracts-final'}
    if {row['name'] for row in execution}!=expected or any(row['exit_code'] for row in execution):
        raise ValueError('The complete final execution has not passed')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,universal_newlines=True).strip()
    if subprocess.check_output(['git','status','--porcelain'],cwd=source).strip():raise ValueError('Qualified source changed')
    destination.mkdir(parents=True)
    frozen=destination/'source';frozen.mkdir()
    names=subprocess.check_output(['git','ls-files','-z','--','rtl','tests','examples'],cwd=source).decode().split('\0')
    for name in filter(None,names):
        target=frozen/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(str(source/name),str(target))
    cases=json.loads((frozen/'tests/cases.json').read_text())
    output=records/'contracts-final.log';case_inventory(cases,output.read_text())
    contracts=destination/'contracts';contracts.mkdir()
    shutil.copyfile(str(output),str(contracts/'results.txt'))
    entries={};representatives={};builds={}
    for case in cases:
        build=source/'.build/tests'/case['top']
        entry={}
        if case.get('expect_compile_error'):
            relative='contracts/compile-rejections/'+case['name']+'.log.gz'
            pack(build/'compile.log',destination/relative);entry['compile_log']=relative
        else:
            relative='contracts/logs/'+case['top']+'/'+case['name']+'.log.gz'
            pack(build/(case['name']+'.log'),destination/relative);entry['log']=relative
            digest=contract_fingerprint(frozen,source,case)
            entry['build_digest']=digest;representatives.setdefault(digest,case)
        entries[case['name']]=entry

    def capture(digest,case):
        original=source/'.build/tests'/case['top']
        if not (original/'source.sha256').exists() or (original/'source.sha256').read_text().strip()!=digest:return False
        folder=contracts/'builds'/digest;folder.mkdir(parents=True,exist_ok=True)
        pack(original/'compile.log',folder/'compile.log.gz')
        shutil.copyfile(str(original/'source.sha256'),str(folder/'source.sha256'))
        for path in (original/'csrc').glob('*.d'):shutil.copyfile(str(path),str(folder/path.name))
        builds[digest]=dict(compile_log=str((folder/'compile.log.gz').relative_to(destination)),
                            source_stamp=str((folder/'source.sha256').relative_to(destination)))
        return True

    # Capture every still-current build before deliberate macro rechecks
    # replace the runner's mutable per-top directory.
    for digest,case in representatives.items():capture(digest,case)
    rechecks=[]
    for digest,case in representatives.items():
        if digest in builds:continue
        folder=contracts/'macro-rechecks';folder.mkdir(exist_ok=True)
        log=folder/(case['name']+'.txt')
        command=[sys.executable,'tests/run.py','--no-cache',case['name']]
        with log.open('w') as stream:p=subprocess.run(command,cwd=source,stdout=stream,stderr=subprocess.STDOUT)
        if p.returncode:raise ValueError('Macro-source recheck failed: '+case['name'])
        case_inventory([case],log.read_text())
        if not capture(digest,case):raise ValueError('Missing immutable macro receipt: '+case['name'])
        rechecks.append(dict(case=case['name'],command=command,exit_code=p.returncode,build_digest=digest,
                             output=str(log.relative_to(destination))))
    for case in cases:
        entry=entries[case['name']]
        if not case.get('expect_compile_error'):entry.update(builds[entry['build_digest']])
    subprocess.check_call([sys.executable,str(source/'tests/scale/revised_evidence.py'),'archive',
                           str(runs/'revised'),'--destination',str(destination/'revised')],cwd=source)
    for name in ['campaign58','acceptance','verdi-applicability']:
        shutil.copytree(str(runs/name),str(destination/name))
    shutil.copytree(str(records),str(destination/'execution'))
    receipt=dict(schema='bw-spec48-run-evidence-v1',state='VERIFIED',source_head=head,
                 contracts=dict(source_root=str(source),exit_code=0,output='contracts/results.txt',cases=entries,
                                macro_rechecks=rechecks),
                 execution=execution,
                 files_sha256={str(p.relative_to(destination)):sha(p) for p in destination.rglob('*') if p.is_file()})
    (destination/'run-evidence.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
    return receipt


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['source','runs','records','destination']:parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args()
    result=collect(args.source.resolve(),args.runs.resolve(),args.records.resolve(),args.destination.resolve())
    print('PASS archived',len(result['contracts']['cases']),'contract cases; missing macro variants rechecked:',
          len(result['contracts']['macro_rechecks']))
