#!/usr/bin/env python3
"""Verify only archived completed nominal rows; pending matrix rows never pass."""
import argparse
import csv
import gzip
import hashlib
import json
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sha = lambda raw: hashlib.sha256(raw).hexdigest()


def unpack(directory, entry):
    compressed = (directory / entry['gzip_file']).read_bytes()
    assert sha(compressed) == entry['gzip_sha256']
    raw = gzip.decompress(compressed)
    assert sha(raw) == entry['uncompressed_sha256'] and len(raw) == entry['uncompressed_bytes']
    return raw


def check_file(entry):
    raw = (HERE / entry['file']).read_bytes()
    assert sha(raw) == entry['sha256'] and len(raw) == entry['bytes']
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current-source', action='store_true')
    args = parser.parse_args()
    proof = json.loads((HERE / 'verification.json').read_text())
    matrix_raw = (HERE / 'completion-matrix.json').read_bytes()
    controller_raw = (HERE / 'controller-checkpoint.json').read_bytes()
    assert sha(matrix_raw) == proof['matrix_sha256'] and sha(controller_raw) == proof['controller_checkpoint_sha256']
    matrix = json.loads(matrix_raw.decode())
    long_contracts = json.loads(check_file(proof['supplemental_files']['long-window-contracts']).decode()) if 'long-window-contracts' in proof['supplemental_files'] else None
    completed = set(proof['completed_profiles'])
    assert proof['status'] == matrix['status'] == 'PARTIAL_NOMINAL_CAMPAIGN'
    assert not proof['nominal_acceptance_passed'] and not matrix['nominal_acceptance_passed']
    assert 0 < len(completed) == proof['completed_profile_count'] == matrix['completed_profile_count'] < 12
    assert completed == set(matrix['completed_profiles']) and len(matrix['profiles']) == 12
    counts = {'ns-short-dense': (51200000, 819200000), 'cycle-short-dense': (51198720, 819179520),
              'ns-long-dense': (51200000, 819200000), 'cycle-long-dense': (102398720, 1638379520),
              'ns-control-clock': (17066239, 273059839), 'cycle-control-clock': (34068478, 545095678)}
    required = {'history-' + scale + '-' + cell for scale in ('common', 'max') for cell in counts}
    assert set(matrix['profiles']) == required and set(matrix['pending_profiles']) == required - completed
    for profile, row in matrix['profiles'].items():
        maximum = profile.startswith('history-max-')
        cell = profile.split('history-max-' if maximum else 'history-common-', 1)[1]
        scopes = 20480 if maximum else 1280
        edges = 79850 if 'control-clock' in cell else 80000
        expected = row['expected_counts']
        assert row['input']['end_ticks'] == 40000000000 and row['input']['scopes'] == scopes
        assert expected['raw_receipts_checked'] == scopes * edges
        assert expected['new_window_publications_checked'] == counts[cell][1 if maximum else 0]
        assert row['verified'] == (profile in completed)
        if profile in completed:
            assert row['state'] == 'VERIFIED_AUDITED' and row['verified_bundle'] == profile + '/bundle.json'
        else:
            assert row['actual_verification'] is None and row['verified_bundle'] is None
            assert row['state'] != 'VERIFIED_AUDITED'
    snapshot = json.loads((HERE / 'source/source-index.json').read_text())
    assert len(snapshot['files']) == proof['source_count'] == 26 and proof['native_header_count'] == 50
    totals = dict(checked_raw=0, checked_windows=0, difference_count=0, episode_records=0, phase_records=0)
    with tempfile.TemporaryDirectory(prefix='bw-history-nominal-recorded-') as temp:
        temporary = Path(temp)
        source = temporary / 'source'
        for name, entry in snapshot['files'].items():
            raw = unpack(HERE / 'source', entry)
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            if name.startswith('rtl/'):
                assert sha(raw) == proof['production_sha256'][name], name
                if args.current_source:
                    assert sha((REPO / name).read_bytes()) == sha(raw), name
        for profile in sorted(completed):
            record = proof['completed_profiles'][profile]
            directory = HERE / profile
            bundle = json.loads((directory / 'bundle.json').read_text())
            attempt = temporary / profile
            attempt.mkdir()
            content = {}
            for name, entry in bundle['files'].items():
                content[name] = unpack(directory, entry)
                (attempt / name).write_bytes(content[name])
            receipt = json.loads(check_file(record['launch']).decode())
            audit = json.loads(check_file(record['recorded_audit']).decode())
            manifest = json.loads(content['manifest.json'].decode())
            result = json.loads(content['verification.json'].decode())
            identity = receipt['identity']
            assert sha(json.dumps(identity, sort_keys=True, separators=(',', ':')).encode()) == receipt['complete_build_identity'] == record['complete_build_identity']
            assert manifest['source_head'] == snapshot['source_head'] == proof['source_head'] == receipt['source_head']
            assert manifest['source_tree'] == snapshot['source_tree'] == proof['source_tree']
            assert not manifest['source_status'] and manifest['state'] == 'VERIFIED' and manifest['checked_pass']
            assert result == manifest['verification'] == record['verification'] == audit['verification'] == matrix['profiles'][profile]['actual_verification']
            expected = matrix['profiles'][profile]['expected_counts']
            assert result['checked_raw'] == expected['raw_receipts_checked'] and result['checked_windows'] == expected['new_window_publications_checked']
            assert result['observed_scopes'] == expected['final_scope_rows'] and result['difference_count'] == 0
            config = manifest['configuration']
            assert config['acceptance_profile'] and config['acceptance_ticket'] == 31 and config['end_ticks'] == 40000000000
            if long_contracts and profile in long_contracts['profiles']:
                facts = long_contracts['profiles'][profile]
                point = next(row for row in csv.DictReader(content['actual.csv'].decode().splitlines())
                             if row['kind'] == 'point' and row['index'] == '0')
                reference = next(row for row in csv.DictReader(content['expected.csv'].decode().splitlines())
                                 if row['kind'] == 'point' and row['index'] == '0')
                assert facts['actual_point0'] == point and facts['reference_point0'] == reference
                assert facts['checked_scopes'] == result['observed_scopes'] and facts['actual_edges_per_scope'] == 80000
                assert facts['actual_end_ticks'] == config['end_ticks'] == 40000000000
                assert facts['checked_publications_per_scope'] == int(point['checked_windows'])
                cycle_long = profile.endswith('cycle-long-dense')
                assert point['window_seq'] == ('79999' if cycle_long else '40000')
                assert point['window_coverage_cycles'] == ('79999' if cycle_long else '0')
                assert point['window_warmup'] == ('1' if cycle_long else '0')
                assert point['window_full'] == point['window_window_valid'] == ('0' if cycle_long else '1')
                assert facts['first_full_publication_ticks'] == (None if cycle_long else 40000000000)
                assert facts['full_publication_count'] == (0 if cycle_long else 1)
                assert result['phase_records'] == facts['phase_records'] == 0
                assert not facts['tail_known'] and not facts['e2e_valid']
                packets = [dict(re.findall(r'(\w+)=([^\s]+)', line))
                           for line in content['simulation.log'].decode().splitlines()
                           if line.startswith('BW_EPISODE ')]
                packet = next(row for row in packets if row['scope'] == point['scope'])
                assert facts['actual_point0_episode'] == packet
                assert packet['status'] == '4' and packet['reason'] == 'OBSERVATION_TRUNCATED'
                assert packet['tail_known'] == packet['e2e_valid'] == '0'
                assert packet['confirm_ticks'] == '40000000000' and point['raw_tick'] == '39999750000'
            assert manifest['source_sha256'] == identity['source_sha256']
            for name, expected_hash in manifest['source_sha256'].items():
                assert snapshot['files'][name]['uncompressed_sha256'] == expected_hash, name
            for name, expected_hash in manifest['evidence_sha256'].items():
                assert sha(content[name]) == expected_hash, name
            for name, expected_hash in manifest['generated_sha256'].items():
                assert sha(content[name]) == expected_hash, name
            for field, name in [('input_sha256', 'input.json'), ('cfg_sha256', 'expect.cfg'), ('expected_sha256', 'expected.csv')]:
                assert sha(content[name]) == manifest[field], field
            assert json.loads(content['diffs.json'].decode()) == []
            assert audit['state'] == 'AUDITED' and audit['original_evidence_not_rewritten']
            assert audit['independent_input_config_reference_regenerated'] and audit['frozen_final_formal_stream_rechecked']
            assert audit['all_recorded_source_header_tool_link_hashes_unchanged']
            headers = identity['native_header_sha256']
            assert len(headers) == audit['native_header_count'] == 50 and headers == audit['native_header_sha256']
            assert '-O' in identity['actual_native_options']
            assert audit['installed_native_link_input_sha256'] == identity['installed_native_link_input_sha256']
            compile_text = content['compile.log'].decode()
            native_line = next(line for line in compile_text.splitlines() if line.startswith('gcc ') and '/bw_slot_settlement.c' in line)
            assert shlex.split(native_line) == audit['actual_native_argv'] and audit['actual_link_command'] in compile_text
            native = content['native-dependencies.d'].decode()
            assert audit['native_dependencies_sha256'] == sha(content['native-dependencies.d'])
            for name in headers:
                assert name in audit['full_dependencies'], name
                if name.endswith(('/svdpi.h', '/vpi_user.h')):
                    assert name in native, name
            cache = json.loads(content['compile-success.json'].decode())
            assert cache['result'] == manifest['compile'] and cache['binary_sha256'] == audit['simulator_sha256']
            digest = sha(json.dumps(manifest['source_sha256'], sort_keys=True).encode() +
                         b''.join(content[name] for name in ('input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv')))
            assert digest == cache['digest'] == manifest['compile_digest']
            assert '+vpi' in manifest['compile']['command'] and '-debug_access' in manifest['compile']['command']
            assert not re.search(r'(?:Warning|Error)-\[', compile_text)
            for stage, filename in [('compile', 'compile.time-v.txt'), ('simulation', 'simulation.time-v.txt')]:
                assert manifest[stage]['state'] == 'COMPLETED' and manifest[stage]['returncode'] == 0
                rss = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', content[filename].decode())
                assert rss and int(rss.group(1)) == manifest[stage]['time_v_peak_rss_kib'] > 0
                assert int(rss.group(1)) == record[stage + '_peak_kib']
            code = '''import pathlib,sys
sys.path.insert(0,sys.argv[1])
from history import HistoryScenario
from generate import generate
from run import verify,keyvalues
scenario=HistoryScenario(sys.argv[3]);attempt=pathlib.Path(sys.argv[2]);fresh=attempt/'regenerated';fresh.mkdir()
generate(scenario,fresh)
for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
    assert (attempt/name).read_bytes()==(fresh/name).read_bytes(),name
before=(attempt/'verification.json').read_bytes();passed,result=verify(scenario,attempt)
assert passed and not result['difference_count'] and before==(attempt/'verification.json').read_bytes()
if scenario.variant=='baseline':
    factor=1000000 if scenario.basis=='ns' else 500000;offset=0 if scenario.basis=='ns' else 250000
    start=(scenario.width+2*scenario.stride)*factor+offset;confirm=(scenario.width+5*scenario.stride)*factor+offset
    phases=[keyvalues(line) for line in (attempt/'simulation.log').read_text().splitlines() if line.startswith('BW_PHASE ')]
    assert len(phases)==(scenario.points+len(scenario.groups) if confirm<=scenario.end else 0)
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
            print('PASS', profile, result['observed_scopes'], 'scopes;', result['checked_raw'], 'raw;', result['checked_windows'], 'windows; original/native/RSS hashes +independent regeneration')
    assert totals == proof['totals']
    controllers = json.loads(controller_raw.decode())
    assert controllers['global_heavy_cap'] == 6 and controllers['common_cap'] == 2
    assert controllers['max30_cap'] == 4 and controllers['max_history_cap'] == 2 and controllers['no_elapsed_auto_increase']
    assert len(controllers['controllers']) == 3
    for record in controllers['controllers'].values():
        assert record['alive_at_checkpoint'] and record['state'] != 'Z'
        check_file(record['script'])
        for entry in record['files'].values():
            check_file(entry)
    for entry in proof['supplemental_files'].values():
        check_file(entry)
    if 'prior-short-bundle-hashes' in proof['supplemental_files']:
        prior = json.loads(check_file(proof['supplemental_files']['prior-short-bundle-hashes']).decode())
        assert set(prior['original_completed_profiles']) <= completed
        for name, expected_hash in prior['file_sha256'].items():
            assert sha((HERE / name).read_bytes()) == expected_hash, name
    reuse = matrix['external_common29_reuse']
    raw = (REPO / reuse['path']).read_bytes()
    assert sha(raw) == reuse['sha256'] and not reuse['contributes_to_twelve_new_profile_count']
    external = json.loads(raw.decode())
    assert external['production_runtime_freeze'] == proof['production_runtime'] and external['production_sha256'] == proof['production_sha256']
    assert not matrix['external_max30_reuse']['contributes_to_twelve_new_profile_count']
    print('PASS PARTIAL checkpoint:', len(completed), '/12 nominal rows;', json.dumps(totals, sort_keys=True), ';remaining rows unaccepted')


if __name__ == '__main__':
    main()
