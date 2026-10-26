#!/usr/bin/env python3
"""Archive and independently replay revised acceptance without VCS or old paths."""
import argparse
import csv
import datetime
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

QUICK = ['topology-quick-ns','topology-quick-cycle','history-revised-ns-seeded',
         'history-revised-cycle-seeded','history-revised-pending']
FULL = ['topology-quick-ns','topology-quick-cycle','topology-max-ns','topology-max-cycle',
        'history-revised-ns-seeded','history-revised-cycle-seeded','history-revised-ns-expiry',
        'history-revised-cycle-expiry','history-revised-ns-deep','history-revised-cycle-deep','history-revised-pending']
COMPONENT_CASES = ['numeric_arithmetic_known','numeric_add_unknown','numeric_mul_unknown','numeric_add_overflow',
                   'numeric_mul_overflow','numeric_queue_range','numeric_subtract_known','numeric_subtract_underflow',
                   'numeric_subtract_unknown','history_trace_ns','history_trace_cycle','phase_delayed',
                   'metrics_stopped_history','reset_member_controls','reset_rewarm']


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()


def save(path,value):
    path.write_text(json.dumps(value,sort_keys=True,indent=2)+'\n')


def require(condition,message):
    if not condition:
        raise ValueError(message)


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def utc_seconds(value):
    for form in ('%Y-%m-%dT%H:%M:%S.%fZ','%Y-%m-%dT%H:%M:%SZ'):
        try:
            return (datetime.datetime.strptime(value,form)-datetime.datetime(1970,1,1)).total_seconds()
        except (ValueError,TypeError):
            pass
    raise ValueError('missing or invalid UTC receipt')


def duration(value,label):
    require(isinstance(value,(int,float)) and math.isfinite(value) and value>=0,'invalid elapsed duration: '+label)
    return value


def audit_run(manifest_path,source=None,attempt=None,native_build=None):
    manifest=json.loads(manifest_path.read_text())
    name=manifest['scenario']
    require(name in FULL,'unknown revised scenario')
    require(manifest.get('schema')=='bw-revised-acceptance-v1','legacy run is not revised evidence')
    require(manifest.get('checked_pass') and manifest.get('state')=='VERIFIED','run did not complete: '+name)
    limit=600 if name.startswith('topology-') else 300
    require(manifest['elapsed_seconds']<=manifest['budget_seconds']<=limit,'run exceeded acceptance budget: '+name)
    source=source or Path(manifest['source_snapshot'])
    attempt=attempt or manifest_path.parent
    native_build=native_build or Path(manifest['build'])
    require(sha(native_build/'compile-success.json')==manifest.get('build_receipt_sha256'),
            'immutable native receipt mismatch: '+name)
    build_receipt=json.loads((native_build/'compile-success.json').read_text())
    recorded_compile=manifest['stages']['compile']
    if recorded_compile['state']=='CACHED':recorded_compile=recorded_compile['original']
    require(build_receipt['stage']==recorded_compile and
            json.loads((native_build/'compile.stage.json').read_text())==recorded_compile,
            'native attempt differs from original run receipt: '+name)
    require(build_receipt['digest']==manifest['compile_digest'] and build_receipt.get('artifacts_sha256'),
            'native fingerprint incomplete: '+name)
    require(manifest['build_identity']['source']==manifest['source_sha256'] and
            manifest['build_identity']['inputs']==manifest['input_sha256'],'build source/input identity mismatch: '+name)
    for relative,expected in manifest['source_sha256'].items():
        require(sha(source/relative)==expected,'source changed: '+relative)
    for filename,expected in manifest['input_sha256'].items():
        require(sha(attempt/filename)==expected,'original input changed: '+filename)
    for filename,expected in manifest['evidence_sha256'].items():
        require(sha(attempt/filename)==expected,'original evidence changed: '+filename)
    for name_stage in ('generation','simulation','verification'):
        require(manifest['stages'][name_stage]['state']=='COMPLETED','incomplete stage: '+name_stage)
    require(manifest['stages']['compile']['state'] in ('COMPLETED','CACHED'),'incomplete compilation')
    identity=hashlib.sha256(json.dumps(manifest['build_identity'],sort_keys=True,separators=(',',':')).encode()).hexdigest()
    require(identity==manifest['compile_digest'],'build identity mismatch')
    module='topology_revised' if name.startswith('topology-') else 'history_revised'
    with tempfile.TemporaryDirectory(prefix='bw-revised-replay-') as temporary:
        replay=Path(temporary)
        command=[sys.executable,str(source/'tests/scale/bounded.py'),'worker',module,name]
        subprocess.check_call(command+['generate',str(replay)],stdout=subprocess.DEVNULL,timeout=300)
        for filename,expected in manifest['input_sha256'].items():
            require((replay/filename).exists() and sha(replay/filename)==expected,'independent input/reference mismatch: '+filename)
        for path in attempt.iterdir():
            if not path.is_file() or path.name in manifest['input_sha256'] or path.name in ('diffs.json','verification.json','manifest.json'):
                continue
            shutil.copyfile(str(path),str(replay/path.name))
        subprocess.check_call(command+['verify',str(replay)],stdout=subprocess.DEVNULL,timeout=300)
        evidence=json.loads((replay/'verification.json').read_text())
        require(evidence.get('difference_count')==0,'independent differences: '+name)
        require(evidence==manifest['verification'],'independent evidence changed: '+name)
    return dict(scenario=name,checked_raw=evidence.get('checked_raw'),checked_windows=evidence.get('checked_windows'),difference_count=0)


def audit_compensating_members(manifest_path):
    """A literal equal-sum substitution must fail the independent edge audit."""
    manifest=json.loads(manifest_path.read_text())
    require(manifest['scenario']=='topology-quick-ns','sensitivity requires fixed quick topology input')
    with tempfile.TemporaryDirectory(prefix='bw-member-sensitivity-') as temporary:
        out=Path(temporary)
        for source in manifest_path.parent.iterdir():
            if source.is_file():
                shutil.copyfile(str(source),str(out/source.name))
        path=out/'actual.csv.edges.csv'
        with path.open() as stream:
            rows=list(csv.DictReader(stream))
        changed=[]
        for row in rows:
            if row['group']=='31' and row['member'] in ('0','7'):
                expected='tb_bw_scale.points[{}].slot.mon'.format(89 if row['member']=='0' else 96)
                require(row['source']==expected,'sensitivity input topology changed')
                row['source']='tb_bw_scale.points[{}].slot.mon'.format(88 if row['member']=='0' else 97)
                changed.append(dict(group=31,member=int(row['member']),original=expected,substituted=row['source']))
        require(len(changed)==2,'sensitivity input edges absent')
        with path.open('w') as stream:
            writer=csv.DictWriter(stream,fieldnames=['group','member','kind','source']);writer.writeheader();writer.writerows(rows)
        # 90+97 == 89+98; the original alternating offset also has equal cardinality.
        source=Path(manifest['source_snapshot'])
        command=[sys.executable,str(source/'tests/scale/bounded.py'),'worker','topology_revised',manifest['scenario'],'verify',str(out)]
        result=subprocess.call(command,stdout=subprocess.DEVNULL,timeout=30)
        differences=json.loads((out/'diffs.json').read_text())
        require(result!=0 and any(d.get('error')=='direct_edge_identity' for d in differences),
                'equal-sum member substitution was accepted')
        return dict(checked_pass=True,substitutions=changed,original_weight_sum=187,substituted_weight_sum=187,
                    difference_kinds=sorted(set(d.get('error','field') for d in differences)))


def validate_suite(value,expected_key=None,run_loader=None):
    require(value.get('schema')=='bw-revised-suite-v1','legacy completion count cannot satisfy revised matrix')
    require(value.get('tier') in ('quick','full') and value.get('cache_mode') in ('cold','hot'),'unknown suite kind')
    if expected_key is not None:
        require(expected_key==value['tier']+'-'+value['cache_mode'],'archive key does not match actual tier/cache mode')
    expected=FULL if value['tier']=='full' else QUICK
    limit=1800 if value['tier']=='full' else (300 if value['cache_mode']=='cold' else 120)
    require(value.get('checked_pass') and value.get('state')=='VERIFIED','suite incomplete')
    require(value['elapsed_seconds']<=value['budget_seconds']==limit,'suite budget mismatch')
    require(value.get('concurrency')==1,'suite was not serial')
    require(value.get('expected_profiles')==expected,'suite expected profile mismatch')
    require([r['name'] for r in value['profiles']]==expected,'missing, duplicate or extra revised profile')
    require(all(r.get('checked_pass') for r in value['profiles']),'unchecked run')
    for stage in value['stages'].values():
        require(stage.get('state')=='COMPLETED','required suite stage incomplete')
    if value['tier']=='full':
        require({'components','common_replay','recorded_replay'}<=set(value['stages']),'required full-suite audits absent')
        require(sorted(c.get('name','') for c in value.get('component_cases',[]))==sorted(COMPONENT_CASES),
                'required H5/H7 component cases absent')
    else:
        require('recorded_replay' in value['stages'],'required daily replay absent')
    receipts=[r.get('manifest') for r in value['profiles']]
    require(all(receipts) and len(set(receipts))==len(receipts),'profiles require distinct actual receipts')
    stage_total=sum(duration(s.get('elapsed_seconds',0),'suite stage') for s in value['stages'].values())
    require(stage_total<=value['elapsed_seconds']+0.05,'stage elapsed duration exceeds entire suite')
    freeze=value.get('freeze',{})
    require(freeze.get('source_head') and freeze.get('source_sha256') and freeze.get('tools'),
            'suite source/tool freeze absent')
    require(freeze.get('common_profile_sources'),'shared source closure absent')
    require(freeze.get('source_digest')==digest(freeze['source_sha256']) and
            freeze.get('tools_digest')==digest(freeze['tools']),'suite source/tool freeze hash mismatch')
    begin=utc_seconds(value.get('started_utc'));end=utc_seconds(value.get('finished_utc'))
    require(end>=begin and abs(end-begin-value['elapsed_seconds'])<0.2,'suite UTC/duration mismatch')
    loader=run_loader or (lambda row:json.loads(Path(row['manifest']).read_text()))
    run_total=0;previous_end=begin
    for row in value['profiles']:
        run=loader(row)
        require(run.get('scenario')==row['name'],'profile label does not match actual run receipt')
        require(run.get('checked_pass') and run.get('state')=='VERIFIED','actual run incomplete')
        require(run.get('source_head')==freeze['source_head'] and run.get('source_status')==freeze.get('source_status'),
                'run source checkout differs from suite freeze')
        require(run.get('build_identity',{}).get('tools')==freeze['tools'],'run tools differ from suite freeze')
        inventory=run.get('source_sha256',{})
        require(all(inventory.get(p)==freeze['source_sha256'].get(p) for p in freeze.get('common_profile_sources',[])) and
                all(freeze['source_sha256'].get(p)==h for p,h in inventory.items()),'run sources differ from suite freeze')
        require(run.get('build_receipt_sha256'),'native attempt receipt not bound to run')
        elapsed=duration(run.get('elapsed_seconds'),'run')
        require(elapsed<=run.get('budget_seconds',-1)<= (600 if row['name'].startswith('topology-') else 300),
                'run budget mismatch')
        first=utc_seconds(run.get('started_utc'));last=utc_seconds(run.get('finished_utc'))
        require(first>=previous_end-0.05 and last<=end+0.05 and last>=first and abs(last-first-elapsed)<0.2,
                'run lies outside serial suite interval')
        previous_end=last;run_total+=elapsed
    for name,stage in value['stages'].items():
        first=utc_seconds(stage.get('started_utc'));last=utc_seconds(stage.get('finished_utc'))
        elapsed=duration(stage.get('elapsed_seconds'),name)
        require(first>=previous_end-0.05 and last<=end+0.05 and last>=first and abs(last-first-elapsed)<0.2,
                'required stage lies outside serial suite interval')
    # JSON sorting is not execution ordering. Establish stage order by timestamps.
    ordered=sorted(value['stages'].values(),key=lambda s:utc_seconds(s['started_utc']))
    previous_end=max([utc_seconds(loader(r)['finished_utc']) for r in value['profiles']]+[begin])
    for stage in ordered:
        require(utc_seconds(stage['started_utc'])>=previous_end-0.05,'required stages overlap')
        previous_end=utc_seconds(stage['finished_utc'])
    overhead=duration(value.get('orchestration_seconds'),'suite orchestration')
    require(abs(value['elapsed_seconds']-run_total-stage_total-overhead)<0.05,
            'suite elapsed total does not reconcile with original receipts')
    require(value.get('freeze_unchanged')==dict(source=True,tools=True,checkout=True,common=True),
            'source/tool/COMMON freeze did not survive the suite')


def _pack(source,destination,index,relative):
    target=destination/(relative+'.gz');target.parent.mkdir(parents=True,exist_ok=True)
    with source.open('rb') as src, target.open('wb') as raw:
        with gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0,compresslevel=6) as compressed:
            shutil.copyfileobj(src,compressed,1024*1024)
    index['files'][relative]=dict(file=relative+'.gz',sha256=sha(source),bytes=source.stat().st_size,gzip_sha256=sha(target))


def verify_components(suite,directory,profile_source):
    """Recompute the component driver's exact source stamp from archived closure."""
    source=directory/'source'
    cases=json.loads((source/'tests/cases.json').read_text())
    canonical={case['name']:case for case in cases}
    require(all(canonical.get(case['name'])==case for case in suite['component_cases']),
            'selected component definitions differ from frozen cases.json')
    required={'tests/run.py','tests/cases.json'}
    for case in suite['component_cases']:
        required.add('tests/'+case['top']+'.sv')
        required.update('tests/'+name for name in case.get('sources',[]))
    require(set(suite['component_source_sha256'])==required,'component source closure missing or extra')
    for relative,expected in suite['component_source_sha256'].items():
        require(expected==suite['freeze']['source_sha256'].get(relative) and sha(source/relative)==expected,
                'component source differs from suite freeze: '+relative)
    rtl=profile_source/'rtl'
    rtl_files=sorted(rtl.glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))+sorted(rtl.glob('*.c'))
    headers=sorted(p for p in rtl.rglob('*') if p.suffix in ('.svh','.vh','.h'))
    original=Path(suite['freeze']['source_root'])
    for case in suite['component_cases']:
        files=rtl_files+[source/'tests'/name for name in case.get('sources',[])]+[source/'tests'/(case['top']+'.sv')]
        h=hashlib.sha256(str(original).encode()+(source/'tests/run.py').read_bytes()+json.dumps(case.get('defines',[])).encode())
        for file in files+headers:
            relative=file.relative_to(profile_source) if file in rtl_files or file in headers else file.relative_to(source)
            h.update(str(original/relative).encode());h.update(file.read_bytes())
        stamp=(directory/'evidence'/case['top']/'source.sha256').read_text().strip()
        require(stamp==h.hexdigest(),'component compiled-source stamp mismatch: '+case['name'])


def verify_stage_receipts(suite,stage_root):
    names={'components':'components','common_replay':'common-replay','recorded_replay':'recorded-replay'}
    for name,receipt in suite['stages'].items():
        stem=names[name]
        actual=json.loads((stage_root/name/(stem+'.stage.json')).read_text())
        require(actual==receipt,'required stage metadata differs from original receipt: '+name)


def archive(output,destination):
    require(not destination.exists(),'archive destination already exists')
    destination.mkdir(parents=True)
    index=dict(schema='bw-revised-archive-v1',files={},suites={},sources={})
    reference_freeze=None
    for tier in ('quick','full'):
        for mode in ('cold','hot'):
            filename='suite-'+tier+'-'+mode+'.json'
            value=json.loads((output/filename).read_text());validate_suite(value,expected_key=tier+'-'+mode)
            freeze=value['freeze']
            require(not freeze['source_status'],'final archive requires clean qualified source checkouts')
            common_freeze={p:freeze['source_sha256'][p] for p in freeze['common_profile_sources']}
            comparable=(freeze['source_head'],common_freeze,freeze['tools'])
            if reference_freeze is None:reference_freeze=comparable
            else:require(comparable==reference_freeze,'cold/hot suites do not share one source/tool freeze')
            _pack(output/filename,destination,index,filename)
            key=tier+'-'+mode;index['suites'][key]=[]
            for row in value['profiles']:
                manifest_path=Path(row['manifest']);manifest=json.loads(manifest_path.read_text())
                relative='runs/'+key+'/'+row['name']
                for file in sorted(manifest_path.parent.iterdir()):
                    if file.is_file():
                        _pack(file,destination,index,relative+'/'+file.name)
                build=Path(manifest['build'])
                for name in ('compile.log','compile.time-v.txt','compile.stage.json','compile-success.json'):
                    require((build/name).exists(),'native build receipt missing: '+name)
                    _pack(build/name,destination,index,relative+'/native-build/'+name)
                for dependency in (build/'csrc').glob('*.d'):
                    _pack(dependency,destination,index,relative+'/native-build/'+dependency.name)
                source_id=hashlib.sha256(json.dumps(manifest['source_sha256'],sort_keys=True).encode()).hexdigest()
                if source_id not in index['sources']:
                    index['sources'][source_id]=manifest['source_sha256']
                    for file in manifest['source_sha256']:
                        _pack(Path(manifest['source_snapshot'])/file,destination,index,'sources/'+source_id+'/'+file)
                index['suites'][key].append(dict(scenario=row['name'],run=relative,source='sources/'+source_id))
            for stage_name in value['stages']:
                directory=Path(value['stages'][stage_name]['cwd'])
                for file in sorted(directory.rglob('*')):
                    if file.is_file():
                        _pack(file,destination,index,'suite-stages/'+key+'/'+stage_name+'/'+str(file.relative_to(directory)))
            for file,expected in value.get('component_source_sha256',{}).items():
                source=Path(__file__).resolve().parents[2]/file
                require(sha(source)==expected,'component source changed before archiving: '+file)
                _pack(source,destination,index,'suite-stages/'+key+'/components/source/'+file)
            if tier=='full':
                proof=value.get('common_proof')
                require(proof and proof.get('files'),'frozen COMMON proof closure absent')
                if 'common_proof' in index:
                    require(proof==index['common_proof'],'cold/hot COMMON identity mismatch')
                else:
                    index['common_proof']=proof
                    for file,expected in proof['files'].items():
                        source=Path(__file__).resolve().parents[2]/file
                        require(sha(source)==expected,'COMMON artifact changed: '+file)
                        _pack(source,destination,index,'common/'+file)
            for file,expected in freeze['source_sha256'].items():
                current=Path(__file__).resolve().parents[2]/file
                require(sha(current)==expected,'current source differs from qualified freeze: '+file)
    save(destination/'index.json',index)
    shutil.copyfile(__file__,str(destination/'verify.py'))
    result=verify(destination)
    save(destination/'verification.json',result)
    return result


def verify(directory):
    index=json.loads((directory/'index.json').read_text())
    require(index.get('schema')=='bw-revised-archive-v1','archive schema mismatch')
    results={}
    with tempfile.TemporaryDirectory(prefix='bw-revised-archive-') as temporary:
        root=Path(temporary)
        for relative,item in index['files'].items():
            require(not Path(relative).is_absolute() and '..' not in Path(relative).parts,'invalid archive path')
            stored=directory/item['file'];require(sha(stored)==item['gzip_sha256'],'compressed artifact changed: '+relative)
            target=root/relative;target.parent.mkdir(parents=True,exist_ok=True)
            with gzip.open(str(stored),'rb') as src,target.open('wb') as out:
                shutil.copyfileobj(src,out,1024*1024)
            require(target.stat().st_size==item['bytes'] and sha(target)==item['sha256'],'artifact changed: '+relative)
        reference_freeze=None;suite_intervals=[];unique_receipts=set()
        for key,rows in index['suites'].items():
            value=json.loads((root/('suite-'+key+'.json')).read_text())
            require([r['scenario'] for r in rows]==value['expected_profiles'],'archive profile mapping changed')
            byname={r['scenario']:r for r in rows}
            loader=lambda row:json.loads((root/byname[row['name']]['run']/'manifest.json').read_text())
            validate_suite(value,expected_key=key,run_loader=loader)
            verify_stage_receipts(value,root/'suite-stages'/key)
            freeze=value['freeze'];common_freeze={p:freeze['source_sha256'][p] for p in freeze['common_profile_sources']}
            comparable=(freeze['source_head'],common_freeze,freeze['tools'])
            if reference_freeze is None:reference_freeze=comparable
            else:require(comparable==reference_freeze,'archive suites do not share one source/tool freeze')
            suite_intervals.append((utc_seconds(value['started_utc']),utc_seconds(value['finished_utc'])))
            for row in value['profiles']:
                require(row['manifest'] not in unique_receipts,'one actual run reused across required suite measurements')
                unique_receipts.add(row['manifest'])
            results[key]=[audit_run(root/r['run']/'manifest.json',root/r['source'],root/r['run'],root/r['run']/'native-build') for r in rows]
            for row in rows:
                manifest=json.loads((root/row['run']/'manifest.json').read_text())
                cache=json.loads((root/row['run']/'native-build/compile-success.json').read_text())
                require(cache['digest']==manifest['compile_digest'] and cache.get('artifacts_sha256'),
                        'native build receipt does not match compiled inputs')
            for case in value.get('component_cases',[]):
                prefix=root/'suite-stages'/key/'components'/'evidence'/case['top']
                text=(prefix/(case['name']+'.log')).read_text()
                if case.get('expect_error'):
                    require('Fatal:' in text and re.search(case['expect_error'],text) and 'TB_PASS' not in text,'component expected error missing')
                else:
                    require('TB_PASS' in text and 'Fatal:' not in text,'component failed')
                require(all(re.search(p,text) for p in case.get('expect_log',[])),'component log contract failed')
                require(all(len(re.findall(p,text))==n for p,n in case.get('expect_counts',{}).items()),'component record count failed')
            for file,expected in value.get('component_source_sha256',{}).items():
                require(sha(root/'suite-stages'/key/'components/source'/file)==expected,'component source snapshot changed')
            if value['tier']=='full':
                require(value.get('common_proof')==index.get('common_proof'),'COMMON proof is not bound to required stage')
                verify_components(value,root/'suite-stages'/key/'components',root/byname['topology-max-ns']['source'])
        previous=0
        for first,last in sorted(suite_intervals):
            require(first>=previous-0.05,'required cold/hot suites overlap')
            previous=last
        proof=index.get('common_proof');require(proof and proof.get('files'),'portable COMMON closure absent')
        for file,expected in proof['files'].items():
            require(sha(root/'common'/file)==expected,'COMMON proof file changed: '+file)
        common_output=subprocess.check_output([sys.executable,str(root/'common'/proof['verifier'])],
            cwd=str(root/'common'),universal_newlines=True,timeout=300)
        require('PASS PARTIAL checkpoint: 6 /12 nominal rows;' in common_output,'frozen COMMON replay did not verify six original rows')
    require(set(results)=={'quick-cold','quick-hot','full-cold','full-hot'},'required cold/hot suite absent')
    return dict(schema='bw-revised-archive-verification-v1',checked_pass=True,difference_count=0,suites=results)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command')
    audit=sub.add_parser('audit-runs');audit.add_argument('manifests',nargs='+',type=Path)
    audit.add_argument('--member-sensitivity',action='store_true')
    make=sub.add_parser('archive');make.add_argument('output',type=Path);make.add_argument('--destination',type=Path,required=True)
    check=sub.add_parser('verify');check.add_argument('directory',type=Path)
    args=parser.parse_args()
    started=time.monotonic()
    if args.command=='audit-runs':
        result=dict(checked_pass=True,runs=[audit_run(p) for p in args.manifests])
        if args.member_sensitivity:
            reference=next(p for p in args.manifests if json.loads(p.read_text())['scenario']=='topology-quick-ns')
            result['member_sensitivity']=audit_compensating_members(reference)
    elif args.command=='archive':
        result=archive(args.output.resolve(),args.destination.resolve())
    elif args.command=='verify':
        result=verify(args.directory.resolve())
    else:
        parser.error('choose audit-runs, archive or verify')
    result['elapsed_seconds']=time.monotonic()-started
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':
    main()
