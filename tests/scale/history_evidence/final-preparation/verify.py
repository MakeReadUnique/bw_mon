#!/usr/bin/env python3
"""Verify recorded final-source preparation without VCS, SDK files or old /tmp paths."""
import argparse
import gzip
import hashlib
import json
import re
import shlex
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sha = lambda data: hashlib.sha256(data).hexdigest()


def unpack(directory, entry):
    compressed = (directory / entry['gzip_file']).read_bytes()
    assert sha(compressed) == entry['gzip_sha256']
    raw = gzip.decompress(compressed)
    assert len(raw) == entry['uncompressed_bytes'] and sha(raw) == entry['uncompressed_sha256']
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current-source', action='store_true')
    args = parser.parse_args()
    proof = json.loads((HERE / 'verification.json').read_text())
    assert proof['status'] == 'SMALL_PREPARATION_PASSED_NOMINAL_NOT_LAUNCHED'
    assert not proof['nominal_acceptance_passed'] and proof['literal_checks'] == 11
    assert proof['source_count'] == 26 and proof['native_header_count'] == 50
    snapshot = json.loads((HERE / 'source/source-index.json').read_text())
    assert snapshot['source_head'] == proof['tested_head'] and len(snapshot['files']) == 26
    windows = {'history-tracer-ns-short-dense': 9600, 'history-tracer-cycle-short-dense': 9560,
               'history-tracer-ns-long-dense': 9600, 'history-tracer-cycle-long-dense': 19160,
               'history-tracer-ns-control-clock': 3199, 'history-tracer-cycle-control-clock': 5959}
    assert set(proof['tracers']) == set(windows)
    totals = dict(checked_raw=0, checked_windows=0, difference_count=0)
    with tempfile.TemporaryDirectory(prefix='bw-history-final-proof-') as temporary:
        temp = Path(temporary)
        source = temp / 'source'
        for name, entry in snapshot['files'].items():
            raw = unpack(HERE / 'source', entry)
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            if name.startswith('rtl/'):
                assert sha(raw) == proof['production_sha256'][name], name
                if args.current_source:
                    assert sha((REPO / name).read_bytes()) == sha(raw), name
        for name in ('test_history.py', 'test_reference.py'):
            completed = subprocess.run([sys.executable, '-B', str(source / 'tests/scale' / name)],
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            assert completed.returncode == 0, completed.stdout.decode()
        for profile, count in windows.items():
            directory = HERE / profile
            summary = proof['tracers'][profile]
            bundle = json.loads((directory / 'bundle.json').read_text())
            attempt = temp / profile
            attempt.mkdir()
            content = {}
            for name, entry in bundle['files'].items():
                content[name] = unpack(directory, entry)
                (attempt / name).write_bytes(content[name])
            receipt_raw = (directory / 'launch.json').read_bytes()
            audit_raw = (directory / 'recorded-audit.json').read_bytes()
            assert sha(receipt_raw) == summary['launch_sha256'] and sha(audit_raw) == summary['audit_sha256']
            receipt = json.loads(receipt_raw.decode())
            audit = json.loads(audit_raw.decode())
            identity = receipt['identity']
            fingerprint = sha(json.dumps(identity, sort_keys=True, separators=(',', ':')).encode())
            assert fingerprint == receipt['complete_build_identity'] == summary['complete_build_identity']
            assert receipt['launcher_sha256'] == sha((HERE / 'launch-recipe.py').read_bytes())
            assert receipt['native_seed']['compile_log_sha256'] == sha(gzip.decompress((HERE / 'native-seed-compile.log.gz').read_bytes()))
            manifest = json.loads(content['manifest.json'].decode())
            result = json.loads(content['verification.json'].decode())
            assert manifest['state'] == 'VERIFIED' and manifest['checked_pass'] and not manifest['source_status']
            assert manifest['source_head'] == snapshot['source_head'] == receipt['source_head']
            assert manifest['source_tree'] == snapshot['source_tree'] == proof['tested_tree']
            assert result == manifest['verification'] == summary['verification'] == audit['verification']
            assert audit['state'] == 'AUDITED' and audit['original_evidence_not_rewritten']
            assert audit['independent_input_config_reference_regenerated'] and audit['frozen_final_formal_stream_rechecked']
            assert audit['all_recorded_source_header_tool_link_hashes_unchanged']
            expected_raw = 18000 if 'control-clock' in profile else 19200
            assert result['checked_raw'] == expected_raw and result['checked_windows'] == count
            assert result['observed_scopes'] == result['expected_scopes'] == 40 and result['difference_count'] == 0
            config = manifest['configuration']
            assert not config['acceptance_profile'] and config['end_ticks'] == 240000000
            assert config['topology']['points'] == 32 and config['topology']['groups'] == 8
            assert manifest['source_sha256'] == identity['source_sha256']
            for name, expected in manifest['source_sha256'].items():
                assert snapshot['files'][name]['uncompressed_sha256'] == expected, name
            for name, expected in manifest['evidence_sha256'].items():
                assert name in content and sha(content[name]) == expected, name
            for name, expected in manifest['generated_sha256'].items():
                assert sha(content[name]) == expected, name
            for field, name in [('input_sha256', 'input.json'), ('cfg_sha256', 'expect.cfg'),
                                ('expected_sha256', 'expected.csv')]:
                assert sha(content[name]) == manifest[field], field
            assert json.loads(content['diffs.json'].decode()) == []
            headers = identity['native_header_sha256']
            assert len(headers) == audit['native_header_count'] == 50 and headers == audit['native_header_sha256']
            assert '-O' in identity['actual_native_options']
            assert audit['installed_native_link_input_sha256'] == identity['installed_native_link_input_sha256']
            compile_text = content['compile.log'].decode()
            native_line = next(line for line in compile_text.splitlines()
                               if line.startswith('gcc ') and '/bw_slot_settlement.c' in line)
            assert shlex.split(native_line) == audit['actual_native_argv']
            assert audit['actual_link_command'] in compile_text
            full_dependencies = audit['full_dependencies']
            native_dependencies = content['native-dependencies.d'].decode()
            for name in headers:
                assert name in full_dependencies, name
                if name.endswith(('/svdpi.h', '/vpi_user.h')):
                    assert name in native_dependencies, name
            assert str(Path(manifest['source_snapshot']) / 'rtl/bw_slot_settlement.c') in native_dependencies
            assert audit['native_dependencies_sha256'] == sha(content['native-dependencies.d'])
            cache = json.loads(content['compile-success.json'].decode())
            assert cache['result'] == manifest['compile']
            assert cache['binary_sha256'] == audit['simulator_sha256']
            digest = sha(json.dumps(manifest['source_sha256'], sort_keys=True).encode() +
                         b''.join(content[name] for name in ('input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv')))
            assert digest == cache['digest'] == manifest['compile_digest']
            command = manifest['compile']['command']
            assert '+vpi' in command and '-debug_access' in command
            assert not re.search(r'(?:Warning|Error)-\[', compile_text)
            for stage, filename in [('compile', 'compile.time-v.txt'), ('simulation', 'simulation.time-v.txt')]:
                assert manifest[stage]['returncode'] == 0
                rss = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', content[filename].decode())
                assert rss and int(rss.group(1)) == manifest[stage]['time_v_peak_rss_kib'] > 0
            code = '''import pathlib,sys
sys.path.insert(0,sys.argv[1])
from history import HistoryScenario
from generate import generate
from run import verify,keyvalues
scenario=HistoryScenario(sys.argv[3]);attempt=pathlib.Path(sys.argv[2]);fresh=attempt/'regenerated';fresh.mkdir()
generate(scenario,fresh)
for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
    assert (attempt/name).read_bytes()==(fresh/name).read_bytes(),name
before=(attempt/'verification.json').read_bytes()
passed,result=verify(scenario,attempt)
assert passed and not result['difference_count'] and before==(attempt/'verification.json').read_bytes()
if scenario.variant=='baseline':
    factor=1000000 if scenario.basis=='ns' else 500000;offset=0 if scenario.basis=='ns' else 250000
    start=(scenario.width+2*scenario.stride)*factor+offset;confirm=(scenario.width+5*scenario.stride)*factor+offset
    phases=[keyvalues(line) for line in (attempt/'simulation.log').read_text().splitlines() if line.startswith('BW_PHASE ')]
    assert len(phases)==(40 if confirm<=scenario.end else 0)
    cardinalities={scenario.identity(k,i):scenario.meta(k,i)[0] for k,i in scenario.scopes()}
    for phase in phases:
        card=cardinalities[phase['scope']]
        expected=dict(kind=2,epoch=0,episode=1,phase=1,result_seq=1,start_ticks=start,confirm_ticks=confirm,end_ticks=scenario.end,
                      start_known=1,end_known=0,start_bytes=64*scenario.clock.lt(start)*card,start_events=scenario.clock.lt(start)*card,
                      end_bytes=64*scenario.clock.edges*card,end_events=scenario.clock.edges*card,reason=2)
        for field,value in expected.items():assert phase[field]==str(value),(sys.argv[3],field)
'''
            subprocess.run([sys.executable, '-B', '-c', code, str(source / 'tests/scale'), str(attempt), profile], check=True)
            for key in totals:
                totals[key] += result[key]
            print('PASS', profile, '40 public scopes; source/native/tool/link/RSS provenance; regenerated independent reference')
    assert totals == proof['totals'] == dict(checked_raw=112800, checked_windows=57078, difference_count=0)
    nominal_counts = {'ns-short-dense': (51200000, 819200000), 'cycle-short-dense': (51198720, 819179520),
                      'ns-long-dense': (51200000, 819200000), 'cycle-long-dense': (102398720, 1638379520),
                      'ns-control-clock': (17066239, 273059839), 'cycle-control-clock': (34068478, 545095678)}
    assert len(proof['nominal_profiles']) == 12
    for name, record in proof['nominal_profiles'].items():
        assert record['state'] == 'NOT_LAUNCHED_FINAL_PRODUCTION'
        raw = (HERE / record['prepared_receipt']).read_bytes()
        assert sha(raw) == record['sha256']
        receipt = json.loads(raw.decode())
        assert receipt['state'] == 'PREPARED_NOT_LAUNCHED' and not receipt.get('runner_pid')
        assert receipt['production_sha256'] == proof['production_sha256']
        maximum = name.startswith('history-max-')
        cell = name.split('history-max-' if maximum else 'history-common-', 1)[1]
        target = record['input']
        counts = record['expected_counts']
        assert counts == receipt['expected_counts']
        assert counts['new_window_publications_checked'] == nominal_counts[cell][1 if maximum else 0]
        edges = 79850 if 'control-clock' in name else 80000
        scopes = 20480 if maximum else 1280
        assert counts['raw_receipts_checked'] == edges * scopes
        assert target['end_ticks'] == 40000000000 and target['scopes'] == scopes
    scheduler = json.loads((HERE / 'common-scheduler-plan.json').read_text())
    assert scheduler['state'] == 'PREPARED_NOT_LAUNCHED'
    assert scheduler['concurrency_cap'] == 2 and scheduler['maximum_history_concurrency'] == 0
    for name, entry in proof['extra_files'].items():
        assert sha((HERE / name).read_bytes()) == entry['sha256'], name
    superseded = proof['superseded_archive']
    archive = HERE / superseded['file']
    assert sha(archive.read_bytes()) == superseded['sha256']
    with tarfile.open(str(archive), 'r:gz') as stream:
        members = {m.name: stream.extractfile(m).read() for m in stream.getmembers() if m.isfile()}
    assert {name: sha(raw) for name, raw in members.items()} == superseded['members']
    operator = json.loads(members['operator/receipt.json'].decode())
    assert operator['classification'] == 'OPERATOR_SUPERSEDED_REVIEW_SOURCE_FIX'
    assert operator['all_four_current_jobs_terminated'] and not superseded['accepted']
    assert not superseded['correctness_or_capacity_failure']
    print('PASS11 literal checks +6 actual small tracers:112800 raw/57078 windows; full12 nominal profiles remain unlaunched')


if __name__ == '__main__':
    main()
