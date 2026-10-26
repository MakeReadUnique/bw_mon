#!/usr/bin/env python3
"""Replay recorded 427-component/42-scene compatibility without VCS or old paths."""
import argparse
import collections
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import shlex
import sys
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
EXPECTED = dict(components=427, tops=168, scenes=42, public_csv_files=672,
                raw=161472, receipts=161472, windows=86375, episodes=518, phases=1350, variations=1868)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return digest(json.dumps(value, sort_keys=True, separators=(',', ':')).encode())


def archive_files(raw):
    result = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
        for member in archive.getmembers():
            name = PurePosixPath(member.name)
            assert member.isfile() and not name.is_absolute() and '..' not in name.parts, ('unsafe member', member.name)
            assert member.name not in result, ('duplicate member', member.name)
            result[member.name] = archive.extractfile(member).read()
    return result


def json_file(files, name):
    return json.loads(files[name].decode())


def dependencies(raw):
    return shlex.split(raw.decode().replace('\\\n', ' ').split(':', 1)[1])


def public_packets(log):
    prefixes = ('BW_EPISODE ', 'BW_PHASE ', 'BW_PHASE_METRICS ', 'BW_VARIATION ', 'BW_LAST_STEADY ',
                'BW_CHECK ', 'BW_SUMMARY ', 'BW_HINT_HIT ', 'BW_HINT_END ')
    records = []
    for line in log.splitlines():
        if line.startswith(prefixes):
            packet = dict(re.findall(r'(\w+)=([^\s]+)', line))
            packet.pop('cfg_file', None)
            records.append(json.dumps((line.split()[0], packet), sort_keys=True))
    return sorted(records)


def verify_components(files, source, campaign, native):
    cases = json.loads(source['tests/cases.json'].decode())
    assert len(cases) == EXPECTED['components'] and len({c['top'] for c in cases}) == EXPECTED['tops']
    stage = campaign['stages']['components']
    script = next(x for x in stage['command'] if x.endswith('/tests/run.py'))
    original_root = Path(script).parents[1]
    assert '--no-cache' in stage['command']
    console = files['components/components.log'].decode()
    outcomes = re.findall(r'^(PASS|FAIL) ([^: ]+):', console, re.M)
    assert outcomes == [('PASS', case['name']) for case in cases], 'missing/duplicate/failed component outcome'
    assert '427/427 contract cases passed' in console
    rtl_sv = sorted((name for name in source if name.startswith('rtl/') and name.endswith('.sv')),
                    key=lambda name: (Path(name).name != 'bw_mon_pkg.sv', Path(name).name))
    rtl_c = sorted(name for name in source if name.startswith('rtl/') and name.endswith('.c'))
    headers = sorted(name for name in source if name.startswith('rtl/') and Path(name).suffix in {'.svh', '.vh', '.h'})
    groups = collections.defaultdict(list)
    for case in cases:
        groups[case['top']].append(case)
        log = files['component-records/'+case['top']+'/'+case['name']+'.log'].decode()
        if case.get('expect_error'):
            assert 'Fatal:' in log and re.search(case['expect_error'], log), case['name']
            assert 'TB_PASS' not in log and 'expected core error did not occur' not in log, case['name']
        else:
            assert 'TB_PASS' in log and 'Fatal:' not in log, case['name']
        assert all(re.search(pattern, log) is not None for pattern in case.get('expect_log', [])), case['name']
        assert all(len(re.findall(pattern, log)) == count for pattern, count in case.get('expect_counts', {}).items()), case['name']
    for top, members in groups.items():
        prefix = 'component-records/'+top+'/'
        log = files[prefix+'compile.log'].decode()
        assert not re.search(r'(?:Warning|Error)-\[', log), top
        native_lines = [line for line in log.splitlines() if ' -c ' in line and line.endswith('/rtl/bw_slot_settlement.c')]
        assert len(native_lines) == 1 and re.search(r'(?<!\S)-O(?:[0-3s])?(?!\S)', native_lines[0]), top
        assert len({tuple(case.get('defines', [])) for case in members}) == 1, ('multiple build variants require separate receipts', top)
        case = members[-1]
        names = rtl_sv+rtl_c+['tests/'+name for name in case.get('sources', [])]+['tests/'+top+'.sv']
        names += headers
        expected = digest(str(original_root).encode()+source['tests/run.py']+json.dumps(case.get('defines', [])).encode()+
                          b''.join(str(original_root/name).encode()+source[name] for name in names))
        assert files[prefix+'source.sha256'].decode() == expected, ('cache fingerprint', top)
        binary = json_file(files, prefix+'binary-identities.json')
        assert 'simv' in binary and any(name.endswith('bw_slot_settlement.o') for name in binary), top
        assert all(re.fullmatch(r'[0-9a-f]{64}', value) for value in binary.values()), top
        receipts = [name for name in files if name.startswith(prefix+'native-dependencies-') and name.endswith('.d')]
        assert receipts, ('missing native dependency receipt', top)
        for name in receipts:
            deps = dependencies(files[name])
            assert deps[0] == str(original_root/'rtl/bw_slot_settlement.c'), (top, deps[0])
            assert {Path(p).name for p in deps[1:]} >= {'svdpi.h', 'vpi_user.h'}, top
            assert set(deps[1:]) <= set(native['native_headers']), top
    assert {name.split('/')[1] for name in files if name.startswith('component-records/')} == set(groups)
    return len(cases), len(groups)


def verify_scenes(files, source, campaign, directory):
    source_dir = directory/'source'
    for name, raw in source.items():
        path = source_dir/name;path.parent.mkdir(parents=True, exist_ok=True);path.write_bytes(raw)
    oracle_dir = source_dir/'tests/acceptance'
    sys.path.insert(0, str(oracle_dir))
    spec = importlib.util.spec_from_file_location('compatibility_frozen_runner', str(oracle_dir/'run.py'))
    runner = importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
    import model
    import analysis
    import evidence
    scenarios = [(s, b) for s in model.PRIMARY for b in ('ns', 'cycle')]+[(s, 'ns') for s in model.SUPPLEMENTAL]
    expected_names = {s+'_'+b for s, b in scenarios}
    assert len(scenarios) == EXPECTED['scenes']
    assert {name.split('/')[1] for name in files if name.startswith('fresh/')} == expected_names
    console = files['e2e/e2e.log'].decode()
    assert re.findall(r'^PASS (\S+) (ns|cycle) ', console, re.M) == scenarios
    old_hashes = json_file(files, 'campaign/historical-assets-before.json')
    builds = json_file(files, 'campaign/e2e-build-identities.json')
    counts = collections.Counter(scenes=0, public_csv_files=0)
    seen_builds = set()
    for scene, basis in scenarios:
        name = scene+'_'+basis
        target = directory/'fresh'/name;target.mkdir(parents=True)
        for path, raw in files.items():
            if path.startswith('fresh/'+name+'/'):
                (target/Path(path).name).write_bytes(raw)
        commands = json.loads((target/'commands.json').read_text())
        comparison = json.loads((target/'comparison.json').read_text())
        c = model.configuration(scene, basis)
        assert commands['configuration'] == c and commands['human_review'] == 'PENDING', name
        assert comparison['status'] == 'PASS' and comparison['human_review'] == 'PENDING', name
        assert commands['base_revision'] == campaign['head'], name
        consumed = evidence.scene_runtime_evidence(source_dir, directory, target, commands, {})
        assert consumed['rtl_sha256'] == campaign['production_sha256'], name
        fingerprint = commands['runtime_evidence']['compile_fingerprint']
        for path, expected in fingerprint['project_sha256'].items():
            assert digest(source[path]) == expected, (name, path)
        build_dir = commands['runtime_evidence']['build_directory'];seen_builds.add(build_dir)
        build = builds[build_dir]
        assert build['source_cache_stamp'] == build['compile_fingerprint_sha256'] == canonical(fingerprint), name
        assert 'simv' in build['binary_sha256'] and any(path.endswith('bw_slot_settlement.o') for path in build['binary_sha256']), name
        assert all(re.fullmatch('[0-9a-f]{64}', value) for value in build['binary_sha256'].values()), name
        rows = model.stimulus(c)
        stimulus = ''.join(' '.join(str(x) for x in row)+'\n' for row in rows)
        assert (target/'stimulus.txt').read_text() == stimulus, name
        assert (target/'expect.cfg').read_text() == model.expectations(c), name
        result = runner.check_trace(c, target, rows)
        frames = model.frame_table(rows);windows = model.window_table(c, rows, frames)
        log = (target/'run.log').read_text()
        assert 'TB_PASS acceptance' in log and not re.search(r'Fatal:|Error-\[|BW_CFG_WARNING', log), name
        lines = log.splitlines()
        summaries = [i for i,line in enumerate(lines) if line.startswith('BW_SUMMARY ')]
        final_packets = ('BW_EPISODE ', 'BW_PHASE ', 'BW_PHASE_METRICS ', 'BW_VARIATION ', 'BW_LAST_STEADY ', 'BW_CHECK ')
        assert len(summaries) == 1 and all(i < summaries[0] for i,line in enumerate(lines) if line.startswith(final_packets)), ('summary precedes final packet', name)
        metrics = analysis.verify(c, rows, frames, windows, log)
        reports = analysis.verify_reports(c, rows, frames, windows, log, (target/'expect.cfg').read_text())
        assert result['counts'] == comparison['counts'] and metrics == comparison['analysis_counts'], name
        assert reports == comparison['report_reference'], name
        assert (target/'waves.fsdb').stat().st_size > 0, name
        old_prefix = 'historical/'+name+'/'
        for old_file in ('trace.tar.gz', 'expect.cfg', 'commands.json', 'comparison.json', 'reference.json', 'source.tar.gz'):
            assert digest(files[old_prefix+old_file]) == old_hashes[name+'/'+old_file], (name, old_file)
        old_trace = archive_files(files[old_prefix+'trace.tar.gz'])
        assert old_trace['stimulus.txt'] == (target/'stimulus.txt').read_bytes(), name
        assert files[old_prefix+'expect.cfg'] == (target/'expect.cfg').read_bytes(), name
        for scope in model.LEAVES:
            assert old_trace[scope+'.csv'] == (target/(scope+'.csv')).read_bytes(), (name, scope)
            counts['public_csv_files'] += 1
        assert public_packets(old_trace['run.log'].decode()) == public_packets(log), ('public final packets changed', name)
        counts.update(result['counts']);counts.update(metrics);counts['scenes'] += 1
    assert set(builds) == seen_builds
    for name in ('review.json', 'verification.json', 'runtime-source.json'):
        assert digest(files['historical/'+name]) == old_hashes[name], name
    return dict(counts)


def verify(proof_path, archive_path, current_source=False, source_root=ROOT):
    proof = json.loads(proof_path.read_text())
    assert proof['schema'] == 'bw-broad-compatibility-v1' and proof['status'] == 'PASS'
    assert proof['expected'] == EXPECTED
    raw = archive_path.read_bytes()
    assert len(raw) == proof['archive']['bytes'] and digest(raw) == proof['archive']['sha256'], 'archive identity'
    files = archive_files(raw)
    assert set(files) == set(proof['members']), 'incomplete archive member inventory'
    for name, content in files.items():
        entry = proof['members'][name]
        assert len(content) == entry['bytes'] and digest(content) == entry['sha256'], ('member identity', name)
    campaign = json_file(files, 'campaign/manifest.json')
    assert campaign['state'] == 'VERIFIED' and campaign['head'] == proof['source_head']
    assert campaign['source_unchanged'] and campaign['tool_native_identities_unchanged'] and campaign['historical_assets_unchanged']
    assert proof['stages'] == campaign['stages'] and set(campaign['stages']) == {'components', 'e2e'}
    for name, stage in campaign['stages'].items():
        assert stage['state'] == 'COMPLETED' and stage['returncode'] == 0 and stage['elapsed_seconds'] > 0, name
        assert json_file(files, name+'/'+name+'.stage.json') == stage, name
    before = json_file(files, 'campaign/source-before.json')
    assert before == json_file(files, 'campaign/source-after.json')
    source = archive_files(files['campaign/source.tar.gz'])
    assert set(source) == set(before)
    assert {name:digest(raw) for name, raw in source.items()} == before
    production = {name:value for name, value in before.items() if name.startswith('rtl/')}
    assert len(production) == 18 and production == proof['production_sha256'] == campaign['production_sha256']
    freeze = json_file(files, 'campaign/reviewed-production-freeze.json')
    assert production == freeze['production_sha256'] and canonical(production) == proof['production_inventory_sha256'] == freeze['production_inventory_sha256']
    expected_current = {name:value for name,value in before.items() if name != 'tests/scale/bounded.py'}
    assert proof['current_source_inputs_sha256'] == expected_current
    assert digest(files['campaign/driver.py']) == campaign['driver_sha256'] == proof['orchestration_source_sha256']['driver.py']
    assert before['tests/scale/bounded.py'] == proof['orchestration_source_sha256']['tests/scale/bounded.py']
    if current_source:
        for name, expected in expected_current.items():
            assert digest((source_root/name).read_bytes()) == expected, ('current compiled/test input differs', name)
    native = json_file(files, 'campaign/tool-native-identities.json')
    assert native == json_file(files, 'campaign/tool-native-identities-after.json')
    assert set(native['executables']) == {'vcs', 'gcc', 'g++', 'python3'}
    assert all(item.get('path') and re.fullmatch('[0-9a-f]{64}', item.get('sha256', '')) for item in native['executables'].values())
    assert [value for name,value in native['native_headers'].items() if Path(name).name == 'bw_slot_settlement.c'] == [production['rtl/bw_slot_settlement.c']]
    assert len(native['native_headers']) == 51  # Actual source plus fifty SDK/system headers.
    assert {Path(name).name for name in native['native_headers']} >= {'svdpi.h', 'vpi_user.h', 'bw_slot_settlement.c'}
    assert all(re.fullmatch('[0-9a-f]{64}', value) for value in native['native_headers'].values())
    components, tops = verify_components(files, source, campaign, native)
    with tempfile.TemporaryDirectory(prefix='bw-compatibility-recorded-') as temporary:
        counts = verify_scenes(files, source, campaign, Path(temporary))
    assert dict(counts, components=components, tops=tops) == EXPECTED, counts
    return dict(counts, components=components, tops=tops, source_head=proof['source_head'],
                current_source_checked=current_source, human_review='Original artifact approval only; no new approval')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=HERE/'verification.json')
    parser.add_argument('--archive', type=Path, default=HERE/'proof.tar.gz')
    parser.add_argument('--current-source', action='store_true')
    parser.add_argument('--source-root', type=Path, default=ROOT)
    args = parser.parse_args()
    result = verify(args.manifest, args.archive, args.current_source, args.source_root.resolve())
    print('PASS 427 components; 42 scenes; 672 equal public CSVs; exact final-packet equality; original human approval unchanged')
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
