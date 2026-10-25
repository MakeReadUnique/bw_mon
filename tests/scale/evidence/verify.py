#!/usr/bin/env python3
"""Check portable archive bytes, original manifests and every final scope row."""
import csv,gzip,hashlib,io,json,subprocess,sys
from fractions import Fraction as F
from pathlib import Path
base=Path(__file__).resolve().parent
sha=lambda data:hashlib.sha256(data).hexdigest()
snapshot=json.loads((base/'source-074c771/source-index.json').read_text())
for name,entry in snapshot['files'].items():
    data=(base/'source-074c771'/entry['gzip_file']).read_bytes()
    assert sha(data)==entry['gzip_sha256'],name
    assert sha(gzip.decompress(data))==entry['uncompressed_sha256'],name
for path in sorted(base.glob('*/bundle.json')):
    bundle=json.loads(path.read_text());contents={}
    for name,entry in bundle['files'].items():
        data=(path.parent/entry['gzip_file']).read_bytes()
        assert sha(data)==entry['gzip_sha256'],(path,name,'gzip')
        raw=gzip.decompress(data);assert sha(raw)==entry['uncompressed_sha256'],(path,name,'original')
        contents[name]=raw
    manifest=json.loads(contents['manifest.json'].decode())
    assert manifest['checked_pass'] and manifest['state']=='VERIFIED'
    assert manifest['configuration']['acceptance_profile']
    assert manifest['simulation']['returncode']==0 and manifest['compile']['returncode']==0
    for name,expected in manifest['source_sha256'].items():assert snapshot['files'][name]['uncompressed_sha256']==expected,name
    for name,expected in manifest['evidence_sha256'].items():
        if name in contents:assert sha(contents[name])==expected,(path,name)
    for name,expected in manifest['generated_sha256'].items():assert sha(contents[name])==expected,(path,name)
    assert json.loads(contents['diffs.json'].decode())==[]
    expected=list(csv.DictReader(io.StringIO(contents['expected.csv'].decode())))
    actual=list(csv.DictReader(io.StringIO(contents['actual.csv'].decode())))
    ref={(r['kind'],r['index']):r for r in expected};obs={(r['kind'],r['index']):r for r in actual}
    assert len(actual)==len(obs)==len(ref)==1280
    assert set(ref)==set(obs)
    for key,e in ref.items():
        for field,value in e.items():
            a=obs[key][field]
            if field in ('window_gbps','window_bpc'):assert abs(F(a)-F(value))<=F(1,10**9)+F(1,10**12)*abs(F(value)),(key,field)
            else:assert a==value,(key,field)
    print('PASS',bundle['scenario'],'1280 archived reference/actual rows; source/gzip/original hashes; zero differences')
campaigns=[base/name/'verify.py' for name in ('repaired-source-3bba72c','final-runtime-467b722')]
campaigns=[path for path in campaigns if path.exists()]
for i,path in enumerate(campaigns):
    subprocess.run([sys.executable,str(path)]+(sys.argv[1:] if i==len(campaigns)-1 else []),check=True)
