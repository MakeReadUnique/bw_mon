#!/usr/bin/env python3
"""Verify recorded scheduling evidence; optional current-source equality check."""
import argparse,hashlib,json,tarfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sha=lambda data:hashlib.sha256(data).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current-source',action='store_true')
    args=parser.parse_args()
    proof=json.loads((HERE/'verification.json').read_text())
    assert proof['cases']==proof['runtime_contracts_verified']==424
    assert proof['top_groups']==proof['cache_stamps_verified']==167
    assert proof['source_unchanged'] and proof['minimum_option_runs']==3
    freeze=None
    for record in proof['archives']:
        path=HERE/record['file']
        assert path.stat().st_size==record['bytes'] and sha(path.read_bytes())==record['sha256'],path
        with tarfile.open(str(path),'r:gz') as archive:
            members=archive.getmembers()
            assert len(members)==len(record['files'])
            for member in members:
                relative=Path(member.name)
                assert member.isfile() and not relative.is_absolute() and '..' not in relative.parts
                data=archive.extractfile(member).read()
                assert sha(data)==record['files'][member.name],member.name
                if record['file'].startswith('components-') and member.name=='freeze.json':freeze=json.loads(data.decode())
        print('PASS',record['file'])
    assert freeze is not None and freeze['head']==proof['source_head']
    if args.current_source:
        for name,digest in freeze['rtl_sha256'].items():assert sha((ROOT/name).read_bytes())==digest,name
        assert {str(p.relative_to(ROOT)) for p in (ROOT/'rtl').rglob('*') if p.is_file()}==set(freeze['rtl_sha256'])
        print('PASS current RTL/C/header equality')
    print('PASS recorded source',proof['source_head'],'424 cases /167 tops /3 minimum-option runs')

if __name__=='__main__':main()
