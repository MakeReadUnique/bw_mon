#!/usr/bin/env python3
"""Verify the frozen final-source small MAX preparation without VCS or /tmp."""
import argparse
import gzip
import hashlib
import json
import re
import subprocess
import sys
import tarfile
import tempfile
from collections import OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(path, entry):
    compressed = path.read_bytes()
    assert sha(compressed) == entry['gzip_sha256'], path
    raw = gzip.decompress(compressed)
    assert len(raw) == entry['uncompressed_bytes'], path
    assert sha(raw) == entry['uncompressed_sha256'], path
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current-source', action='store_true')
    args = parser.parse_args()
    proof = json.loads((HERE / 'verification.json').read_text())
    assert proof['status'] == 'SMALL_PREPARATION_PASSED_NOMINAL_NOT_LAUNCHED'
    assert proof['literal_checks'] == 11 and len(proof['tracers']) == 4
    assert not proof['nominal_acceptance_passed']
    source_index = json.loads((HERE / 'source/source-index.json').read_text())
    assert source_index['source_head'] == proof['tested_head']
    assert len(source_index['files']) == 26
    totals = {'checked_raw': 0, 'checked_windows': 0, 'difference_count': 0}
    with tempfile.TemporaryDirectory(prefix='bw-max-final-preparation-') as temp:
        temporary = Path(temp)
        source = temporary / 'source'
        for name, entry in source_index['files'].items():
            raw = unpack(HERE / 'source' / entry['gzip_file'], entry)
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            if name.startswith('rtl/'):
                assert sha(raw) == proof['production_sha256'][name], name
                if args.current_source:
                    assert sha((REPO / name).read_bytes()) == sha(raw), name
        nominal_windows = {'max-ns': 81920000, 'max-cycle': 81899520,
                           'max-ns-short-unknown': 81920000,
                           'max-cycle-short-reset': 81899519}
        assert set(proof['nominal_profiles']) == set(nominal_windows)
        for profile, window_count in nominal_windows.items():
            record = proof['nominal_profiles'][profile]
            assert record['state'] == 'NOT_LAUNCHED_FINAL_PRODUCTION'
            launch = json.loads((HERE / record['prepared_receipt']).read_text())
            assert launch['state'] == 'PREPARED_NOT_LAUNCHED' and not launch.get('runner_pid')
            assert launch['production_sha256'] == proof['production_sha256']
            assert launch['expected_counts']['raw_receipts_checked'] == 1638400000
            assert launch['expected_counts']['new_window_publications_checked'] == window_count
            assert record['input']['topology']['points'] == 16384
            assert record['input']['topology']['groups'] == 4096
            assert record['input']['end_ticks'] == 40000000000
        for name in ('test_maximum.py', 'test_reference.py'):
            result = subprocess.run([sys.executable, '-B', str(source / 'tests/scale' / name)],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert result.returncode == 0, result.stdout.decode()
        for profile, record in proof['tracers'].items():
            directory = HERE / profile
            bundle = json.loads((directory / 'bundle.json').read_text())
            attempt = temporary / profile
            attempt.mkdir()
            content = {}
            for name, entry in bundle['files'].items():
                content[name] = unpack(directory / entry['gzip_file'], entry)
                (attempt / name).write_bytes(content[name])
            manifest = json.loads(content['manifest.json'].decode())
            result = json.loads(content['verification.json'].decode())
            assert manifest['state'] == 'VERIFIED' and manifest['checked_pass']
            assert manifest['source_head'] == proof['tested_head']
            assert manifest['source_tree'] == source_index['source_tree']
            assert not manifest['source_status']
            assert manifest['verification'] == result == record['verification']
            assert result['checked_raw'] == 26880 and result['observed_scopes'] == 56
            assert result['checked_windows'] == record['expected_windows']
            assert result['difference_count'] == 0
            assert json.loads(content['diffs.json'].decode()) == []
            config = manifest['configuration']
            assert not config['acceptance_profile'] and config['end_ticks'] == 240000000
            assert config['topology']['points'] == 32 and config['topology']['groups'] == 24
            assert config['topology']['depth'] == 8 and config['topology']['max_direct_parents'] == 16
            for name, expected in manifest['source_sha256'].items():
                assert source_index['files'][name]['uncompressed_sha256'] == expected, name
            for name, expected in manifest['evidence_sha256'].items():
                assert name in content and sha(content[name]) == expected, (profile, name)
            for name, expected in manifest['generated_sha256'].items():
                assert sha(content[name]) == expected, (profile, name)
            for field, name in [('input_sha256', 'input.json'), ('cfg_sha256', 'expect.cfg'),
                                ('expected_sha256', 'expected.csv')]:
                assert sha(content[name]) == manifest[field], (profile, field)
            command = manifest['compile']['command']
            assert '+vpi' in command and '-debug_access' in command
            assert any(part.endswith('/rtl/bw_slot_settlement.c') for part in command)
            native = content['native-dependencies.d'].decode()
            full_dependencies = record['launch']['native_dependencies']
            for header in record['launch']['identity']['native_header_sha256']:
                assert header in full_dependencies, (profile, header)
                if header.endswith(('/svdpi.h', '/vpi_user.h')):
                    assert header in native, (profile, header)
            cache = json.loads(content['compile-success.json'].decode())
            assert cache['result'] == manifest['compile']
            assert cache['binary_sha256'] == record['postrun']['simulator_sha256']
            assert record['postrun']['source_header_link_hashes_unchanged']
            assert record['postrun']['native_dependencies_sha256'] == sha(content['native-dependencies.d'])
            # The original receipt preserves the pre-serialization ordering of
            # numeric graph keys. Keep those bytes/order when checking its
            # fingerprint; the summarized proof sorts JSON string keys again.
            original_launch = json.loads((directory / 'launch.json').read_text(),
                                         object_pairs_hook=OrderedDict)
            assert original_launch == record['launch']
            identity = original_launch['identity']
            assert len(identity['source_sha256']) == 26
            assert len(identity['native_header_sha256']) == 50
            assert original_launch['complete_build_identity'] == sha(json.dumps(identity).encode())
            assert original_launch['launcher_sha256'] == sha((HERE / 'launch-recipe.py').read_bytes())
            digest = sha(json.dumps(manifest['source_sha256'], sort_keys=True).encode() +
                         b''.join(content[name] for name in ('input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv')))
            assert digest == cache['digest'] == manifest['compile_digest']
            assert not re.search(r'(?:Warning|Error)-\[', content['compile.log'].decode())
            for stage, name in [('compile', 'compile.time-v.txt'), ('simulation', 'simulation.time-v.txt')]:
                assert manifest[stage]['returncode'] == 0
                match = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', content[name].decode())
                assert match and int(match.group(1)) == manifest[stage]['time_v_peak_rss_kib'] > 0
            code = '''import pathlib,sys
sys.path.insert(0,sys.argv[1])
from maximum import build_scenario
from generate import generate
from run import verify
attempt=pathlib.Path(sys.argv[2]); fresh=attempt/'regenerated'; fresh.mkdir()
scenario=build_scenario(sys.argv[3]); generate(scenario,fresh)
for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
    assert (attempt/name).read_bytes()==(fresh/name).read_bytes(),name
before=(attempt/'verification.json').read_bytes()
passed,evidence=verify(scenario,attempt)
assert passed and not evidence['difference_count']
assert before==(attempt/'verification.json').read_bytes()
'''
            subprocess.run([sys.executable, '-B', '-c', code, str(source / 'tests/scale'),
                            str(attempt), profile], check=True)
            for key in totals:
                totals[key] += result[key]
            print('PASS', profile, '56 public scopes; original/source/native/config/RSS hashes; regenerated independent reference')
    assert totals == proof['totals'] == {'checked_raw': 107520, 'checked_windows': 5263, 'difference_count': 0}
    for name, entry in proof['extra_files'].items():
        assert sha((HERE / name).read_bytes()) == entry['sha256'], name
    archive = proof['superseded_archive']
    path = HERE / archive['file']
    assert sha(path.read_bytes()) == archive['sha256']
    with tarfile.open(str(path), 'r:gz') as stream:
        files = {member.name: stream.extractfile(member).read() for member in stream.getmembers() if member.isfile()}
    assert {name: sha(raw) for name, raw in files.items()} == archive['members']
    stopped = json.loads(files['operator/receipt.json'].decode())
    assert stopped['classification'] == 'OPERATOR_SUPERSEDED_REVIEW_SOURCE_FIX'
    assert stopped['all_four_current_jobs_terminated']
    print('PASS final-source preparation:11 literal checks,4 small tracers,107520 raw,5263 windows; full MAX remains unrun')


if __name__ == '__main__':
    main()
