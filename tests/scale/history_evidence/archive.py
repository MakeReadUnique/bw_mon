#!/usr/bin/env python3
"""Portable recorded-history evidence; never a simulation/reference dependency."""
import argparse,csv,gzip,hashlib,io,json,subprocess
from fractions import Fraction as F
from pathlib import Path
BASE=Path(__file__).resolve().parent
REPO=BASE.parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def store(out,name,raw):
    target=out/(name+'.gz');target.parent.mkdir(parents=True,exist_ok=True)
    with target.open('wb') as f:
        with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0,compresslevel=9) as z:z.write(raw)
    return dict(gzip_file=name+'.gz',gzip_sha256=sha(target.read_bytes()),uncompressed_sha256=sha(raw),uncompressed_bytes=len(raw))
def pack(path,source):
    m=json.loads(path.read_text());assert m['state']=='VERIFIED' and m['checked_pass'],'unfinished/failed profiles cannot be packaged as passed'
    attempt=path.parent;out=BASE/m['scenario'];out.mkdir(exist_ok=True)
    source_name='source-'+m['source_head'][:7];snapshot=BASE/source_name;snapshot.mkdir(exist_ok=True);index=dict(source_head=m['source_head'],files={})
    for name,expected in m['source_sha256'].items():
        raw=(source/name).read_bytes() if source else subprocess.check_output(['git','show',m['source_head']+':'+name],cwd=str(REPO))
        assert sha(raw)==expected,('source mismatch',name)
        index['files'][name]=store(snapshot,name,raw)
    (snapshot/'source-index.json').write_text(json.dumps(index,indent=2,sort_keys=True)+'\n')
    files={name:attempt/name for name in ['input.json','expect.cfg','expected.csv','actual.csv','diffs.json','verification.json','manifest.json','simulation.log','simulation.time-v.txt','input_pkg.sv','checker.sv','tb_bw_scale.sv']}
    files['compile.log']=Path(m['compile']['log']);files['compile.time-v.txt']=Path(m['compile']['time_v'])
    launch=attempt.parents[2]/'launch.json'
    if launch.exists():files['launch.json']=launch
    bundle=dict(scenario=m['scenario'],source_head=m['source_head'],source_snapshot='../'+source_name+'/source-index.json',original_manifest=str(path),files={})
    for name,file in files.items():bundle['files'][name]=store(out,name,file.read_bytes())
    (out/'bundle.json').write_text(json.dumps(bundle,indent=2,sort_keys=True)+'\n')
    print('PACKED',m['scenario'],m['verification']['checked_raw'],m['verification']['checked_windows'])
def read_checked(root,entry):
    data=(root/entry['gzip_file']).read_bytes();assert sha(data)==entry['gzip_sha256']
    raw=gzip.decompress(data);assert sha(raw)==entry['uncompressed_sha256'];return raw

def verify():
    for path in sorted(BASE.glob('*/bundle.json')):
        b=json.loads(path.read_text());contents={n:read_checked(path.parent,e) for n,e in b['files'].items()}
        source_index=(path.parent/b['source_snapshot']).resolve();snapshot=json.loads(source_index.read_text())
        for entry in snapshot['files'].values():read_checked(source_index.parent,entry)
        m=json.loads(contents['manifest.json'].decode());assert m['checked_pass'] and m['state']=='VERIFIED'
        assert m['configuration']['acceptance_profile'] and m['configuration']['acceptance_ticket']==31
        assert m['simulation']['returncode']==0 and m['compile']['returncode']==0
        for n,h in m['source_sha256'].items():assert snapshot['files'][n]['uncompressed_sha256']==h
        for n,h in m['evidence_sha256'].items():
            if n in contents:assert sha(contents[n])==h
        for n,h in m['generated_sha256'].items():assert sha(contents[n])==h
        assert json.loads(contents['diffs.json'].decode())==[]
        ref=list(csv.DictReader(io.StringIO(contents['expected.csv'].decode())));obs=list(csv.DictReader(io.StringIO(contents['actual.csv'].decode())))
        a={(r['kind'],r['index']):r for r in obs};e={(r['kind'],r['index']):r for r in ref}
        expected_scopes=m['configuration']['topology']['points']+m['configuration']['topology']['groups']
        assert len(obs)==len(a)==len(e)==expected_scopes and set(a)==set(e)
        for key,row in e.items():
            for field,value in row.items():
                actual=a[key][field]
                if field in ('window_gbps','window_bpc'):assert abs(F(actual)-F(value))<=F(1,10**9)+F(1,10**12)*abs(F(value)),(key,field)
                else:assert actual==value,(key,field)
        v=m['verification'];assert sum(int(r['checked_records']) for r in obs)==v['checked_raw'] and sum(int(r['checked_windows']) for r in obs)==v['checked_windows']
        print('PASS',b['scenario'],expected_scopes,'source/archive/original/reference/actual rows')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['pack','verify']);p.add_argument('manifests',nargs='*',type=Path);p.add_argument('--source-root',type=Path);args=p.parse_args()
    if args.action=='pack':
        for path in args.manifests:pack(path.resolve(),args.source_root)
    else:verify()
