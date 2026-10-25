#!/usr/bin/env python3
"""Verify recorded preparation bytes and outcomes without compiling a DUT."""
import argparse
import csv
import hashlib
import io
import json
from fractions import Fraction
from pathlib import Path
import tarfile


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current-source', action='store_true')
    args = parser.parse_args()
    proof = json.loads((HERE / 'verification.json').read_text())
    archives = {}
    for name, expected in proof['archives'].items():
        blob = (HERE / name).read_bytes()
        assert len(blob) == expected['bytes'] and digest(blob) == expected['sha256'], name
        with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
            files = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
        assert {n: digest(b) for n, b in files.items()} == expected['files'], name
        archives[name] = files
    files = archives['current-tracers-1508f8f.tar.gz']
    summary = json.loads(files['summary.json'].decode())
    assert summary['literal_checks'] == 11 and summary['total_differences'] == 0
    assert summary['total_raw'] == 107520 and summary['total_windows'] == 5263
    assert len(summary['public_tracers']) == 4
    for record in summary['public_tracers']:
        base = 'runs/' + record['profile'] + '/'
        manifest = json.loads(files[base + 'manifest.json'].decode())
        assert manifest['state'] == 'VERIFIED' and manifest['checked_pass']
        assert manifest['source_head'] == proof['tested_head']
        assert manifest['source_sha256'] == proof['source_sha256']
        assert json.loads(files[base + 'diffs.json'].decode()) == []
        expected = list(csv.DictReader(io.StringIO(files[base + 'expected.csv'].decode())))
        actual = list(csv.DictReader(io.StringIO(files[base + 'actual.csv'].decode())))
        expected = {(r['kind'], r['index']): r for r in expected}
        actual = {(r['kind'], r['index']): r for r in actual}
        assert len(expected) == 56 and set(expected) == set(actual)
        for key, row in expected.items():
            for field, value in row.items():
                observed = actual[key][field]
                if field in ('window_gbps', 'window_bpc'):
                    assert abs(Fraction(observed) - Fraction(value)) <= Fraction(1, 10**9) + Fraction(1, 10**12) * abs(Fraction(value))
                else:
                    assert observed == value, (key, field)
        assert sum(int(r['checked_records']) for r in actual.values()) == 26880
        command = manifest['compile']['command']
        assert '+vpi' in command and '-debug_access' in command and '-debug_access+all' not in command
        assert any(s.endswith('/rtl/bw_slot_settlement.c') for s in command)
        assert 'SCALE_PASS points=32 groups=24 scopes=56 checked_raw=26880 end_ticks=240000000' in files[base + 'simulation.log'].decode()
    old = json.loads(archives['superseded-2d5c685-records.tar.gz']['classification.json'].decode())
    assert len(old['attempts']) == 5 and all(not a['accepted'] and not a['capacity_failure'] for a in old['attempts'])
    assert sum(a['classification'] == 'infrastructure-license-shutdown' for a in old['attempts']) == 1
    if args.current_source:
        for name, expected in proof['source_sha256'].items():
            assert digest((REPO / name).read_bytes()) == expected, name
    print('VERIFIED:11 literal checks,4 public tracers,107520 raw,5263 windows,0 differences; native MAX remains pending')


if __name__ == '__main__':
    main()
