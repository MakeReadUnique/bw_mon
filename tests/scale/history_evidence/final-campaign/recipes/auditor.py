#!/usr/bin/env python3
"""Audit one completed fixed history profile; never compile or simulate."""
import argparse
import datetime
import importlib.util
import json
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile

LAUNCHER = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-launch.py')
spec = importlib.util.spec_from_file_location('history_launch', str(LAUNCHER))
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)


def audit(profile):
    receipt_path = launch.BASE / (profile + '-launch.json')
    receipt = json.loads(receipt_path.read_text())
    output = pathlib.Path(receipt['output_root'])
    manifests = list(output.glob('runs/*/*/manifest.json'))
    assert len(manifests) == 1
    manifest_path = manifests[0]
    manifest = json.loads(manifest_path.read_text())
    attempt = manifest_path.parent
    build = pathlib.Path(manifest['compile']['cwd'])
    consumed = pathlib.Path(manifest['source_snapshot'])
    identity = receipt['identity']
    assert receipt['complete_build_identity'] == launch.fingerprint(identity)
    assert receipt['launcher_sha256'] == launch.sha(LAUNCHER)
    assert manifest['state'] == 'VERIFIED' and manifest['checked_pass']
    assert not manifest['source_status'] and manifest['source_head'] == receipt['source_head']
    assert manifest['source_sha256'] == identity['source_sha256']
    for name, expected in manifest['source_sha256'].items():
        assert launch.sha(consumed / name) == expected == launch.sha(launch.SOURCE / name), name
    for name, expected in manifest['evidence_sha256'].items():
        assert launch.sha(attempt / name) == expected, name
    for name, expected in manifest['generated_sha256'].items():
        assert launch.sha(attempt / name) == expected == launch.sha(build / name), name
    for record in identity['tools'].values():
        assert launch.sha(record['executable']) == record['sha256']
    for name, expected in identity['native_header_sha256'].items():
        assert launch.sha(name) == expected, name
    assert len(identity['native_header_sha256']) == 50
    compile_text = pathlib.Path(manifest['compile']['log']).read_text()
    native_line = next(line for line in compile_text.splitlines()
                       if line.startswith('gcc ') and '/bw_slot_settlement.c' in line)
    native_argv = shlex.split(native_line)
    native_source = next(token for token in native_argv if token.endswith('/bw_slot_settlement.c'))
    native_options = [token for token in native_argv[1:] if token not in ('-c', native_source)]
    assert native_options == identity['actual_native_options'] and '-O' in native_options
    dependency_query = ['gcc', '-M'] + native_options + [native_source]
    dependencies = subprocess.check_output(dependency_query, cwd=str(build), universal_newlines=True)
    paths = shlex.split(dependencies.replace('\\\n', ' ').split(':', 1)[1])
    actual_headers = {name: launch.sha(name) for name in paths
                      if pathlib.Path(name).resolve() != pathlib.Path(native_source).resolve()}
    assert actual_headers == identity['native_header_sha256']
    link_line = next(line for line in compile_text.splitlines() if line.startswith('g++ '))
    assert launch.link_inputs(link_line) == identity['installed_native_link_input_sha256']
    native = build / 'csrc/bw_slot_settlement.d'
    vcs_dependencies = native.read_text()
    assert str(consumed / 'rtl/bw_slot_settlement.c') in vcs_dependencies
    sdk_headers = [name for name in actual_headers if name.endswith(('/svdpi.h', '/vpi_user.h'))]
    assert len(sdk_headers) == 2 and all(name in vcs_dependencies for name in sdk_headers)
    cache = json.loads((build / 'compile-success.json').read_text())
    assert cache['result'] == manifest['compile'] and cache['digest'] == manifest['compile_digest']
    assert cache['binary_sha256'] == launch.sha(build / 'simv')
    command = manifest['compile']['command']
    assert '+vpi' in command and '-debug_access' in command and str(consumed / 'rtl/bw_slot_settlement.c') in command
    assert not re.search(r'(?:Warning|Error)-\[', compile_text)
    for stage in ('compile', 'simulation'):
        result = manifest[stage]
        assert result['state'] == 'COMPLETED' and result['returncode'] == 0
        rss = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', pathlib.Path(result['time_v']).read_text())
        assert rss and int(rss.group(1)) == result['time_v_peak_rss_kib'] > 0
    expected = receipt['expected_counts']
    result = manifest['verification']
    assert result['checked_raw'] == expected['raw_receipts_checked']
    assert result['checked_windows'] == expected['new_window_publications_checked']
    assert result['observed_scopes'] == expected['final_scope_rows'] and result['difference_count'] == 0
    code = '''import pathlib,shutil,sys,tempfile
sys.path.insert(0,sys.argv[1])
from history import HistoryScenario
from generate import generate
from run import verify,keyvalues
scenario=HistoryScenario(sys.argv[3]); original=pathlib.Path(sys.argv[2])
with tempfile.TemporaryDirectory(prefix='bw-history31-audit-') as tmp:
    attempt=pathlib.Path(tmp)/'attempt';attempt.mkdir();fresh=pathlib.Path(tmp)/'regenerated';fresh.mkdir()
    for path in original.iterdir():
        if path.is_file():shutil.copyfile(str(path),str(attempt/path.name))
    generate(scenario,fresh)
    for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
        assert (attempt/name).read_bytes()==(fresh/name).read_bytes(),name
    before=(attempt/'verification.json').read_bytes()
    passed,result=verify(scenario,attempt)
    assert passed and not result['difference_count'] and before==(attempt/'verification.json').read_bytes()
    # Independent constant-flow N3/K4 boundaries for the baseline history cells.
    # Both long cells end before sufficient full-window evidence exists.
    if scenario.variant=='baseline':
        factor=1000000 if scenario.basis=='ns' else 500000
        offset=0 if scenario.basis=='ns' else 250000
        start=(scenario.width+2*scenario.stride)*factor+offset
        confirm=(scenario.width+5*scenario.stride)*factor+offset
        lines=(attempt/'simulation.log').read_text().splitlines()
        phases=[keyvalues(line) for line in lines if line.startswith('BW_PHASE ')]
        should_confirm=confirm<=scenario.end
        assert len(phases)==(scenario.points+len(scenario.groups) if should_confirm else 0)
        if should_confirm:
            by_scope={scenario.identity(k,i):1 if k=='point' else len(scenario.leaves[i]) for k,i in scenario.scopes()}
            for phase in phases:
                card=by_scope[phase['scope']]
                expected=dict(kind=2,epoch=0,episode=1,phase=1,result_seq=1,start_ticks=start,confirm_ticks=confirm,
                              end_ticks=scenario.end,start_known=1,end_known=0,start_bytes=64*scenario.clock.lt(start)*card,
                              start_events=scenario.clock.lt(start)*card,end_bytes=64*scenario.clock.edges*card,
                              end_events=scenario.clock.edges*card,reason=2)
                for field,value in expected.items():assert phase[field]==str(value),(phase['scope'],field,phase[field],value)
'''
    subprocess.run([sys.executable, '-B', '-c', code, str(launch.SOURCE / 'tests/scale'), str(attempt), profile], check=True)
    record = dict(profile=profile, state='AUDITED', audited_utc=datetime.datetime.utcnow().isoformat() + 'Z',
                  manifest=str(manifest_path), verification=result, source_hash_count=len(manifest['source_sha256']),
                  complete_build_identity=receipt['complete_build_identity'], native_header_count=len(actual_headers),
                  native_header_sha256=actual_headers, actual_native_argv=native_argv,
                  full_dependency_query_argv=dependency_query, full_dependencies=dependencies,
                  actual_link_command=link_line, installed_native_link_input_sha256=launch.link_inputs(link_line),
                  native_dependencies_sha256=launch.sha(native), native_object_sha256=launch.sha(build / 'csrc/bw_slot_settlement.o'),
                  simulator_sha256=cache['binary_sha256'], all_recorded_source_header_tool_link_hashes_unchanged=True,
                  independent_input_config_reference_regenerated=True, frozen_final_formal_stream_rechecked=True,
                  baseline_phase_boundaries_independently_checked=manifest['configuration']['config']['variant'] == 'baseline',
                  original_evidence_not_rewritten=True)
    launch.write(output / 'recorded-audit.json', record)
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile')
    result = audit(parser.parse_args().profile)
    print(json.dumps(dict(profile=result['profile'], state=result['state'], native_headers=result['native_header_count'],
                          raw=result['verification']['checked_raw'], windows=result['verification']['checked_windows'])))
