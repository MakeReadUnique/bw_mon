#!/usr/bin/env python3
"""Qualify recorded MAX results without compiling, simulating, or closing tickets."""
import argparse
from collections import OrderedDict
import datetime
import gzip
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


NOMINAL = {'max-ns': 81920000, 'max-cycle': 81899520,
           'max-ns-short-unknown': 81920000, 'max-cycle-short-reset': 81899519}
PROFILE_CONFIG = {'max-ns': ('ns', 100, 10, 'baseline'),
                  'max-cycle': ('cycle', 200, 20, 'baseline'),
                  'max-ns-short-unknown': ('ns', 10, 10, 'unknown'),
                  'max-cycle-short-reset': ('cycle', 20, 20, 'reset')}


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            digest.update(block)
    return digest.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_manifest(manifest, allow_tracer=False):
    profile = manifest['scenario']
    nominal = profile in NOMINAL
    require(nominal or allow_tracer, 'tracer is preparation only; nominal qualification refused')
    require(manifest['state'] == 'VERIFIED' and manifest.get('checked_pass'),
            'recorded profile has not completed verification')
    require(not manifest['source_status'], 'consumed source was not clean')
    config, result = manifest['configuration'], manifest['verification']
    require(result['difference_count'] == 0, 'recorded differences remain')
    if nominal:
        topology = config['topology']
        require(tuple(topology[key] for key in ('points', 'groups', 'direct_edges', 'depth', 'max_direct_parents'))
                == (16384, 4096, 65536, 8, 16), 'nominal topology limits changed')
        require(topology['graph_sha256'] == '736a6660a63a4596fe2d41e45e241c4024c98c05957c13f297b31f0b67a7f2a3'
                and topology['ungrouped_points'] == [16383], 'nominal topology input changed')
        require(config['acceptance_profile'] and config['acceptance_ticket'] == 30
                and config['end_ticks'] == 40000000000 and config['expected_edges'] == 80000,
                'nominal duration or edge budget changed')
        require(tuple(config['config'][key] for key in ('basis', 'width', 'stride', 'variant'))
                == PROFILE_CONFIG[profile], 'nominal window or intervention changed')
        require((result['checked_raw'], result['expected_raw'], result['observed_scopes'], result['expected_scopes'])
                == (1638400000, 1638400000, 20480, 20480), 'nominal raw/scope count changed')
        require(result['checked_windows'] == result['expected_windows'] == NOMINAL[profile],
                'nominal publication count changed')
        episodes = 20481 if profile == 'max-cycle-short-reset' else 20480
        require(result['episode_records'] == episodes and sum(result['report_conclusions'].values()) == 12 * episodes,
                'nominal final result count changed')
    else:
        require(profile in ('max-tracer-ns', 'max-tracer-cycle', 'max-tracer-unknown', 'max-tracer-reset')
                and not config['acceptance_profile'], 'unrecognized preparation profile')
    return nominal


# The consumed reference is executed in a fresh process and only writes into a
# temporary copy. It never imports current production code or reruns a simulator.
REPLAY_CODE = r'''
import json,pathlib,sys
sys.path.insert(0,sys.argv[1])
from maximum import build_scenario
from generate import generate
from run import verify,keyvalues
attempt=pathlib.Path(sys.argv[2]);fresh=pathlib.Path(sys.argv[3])
scenario=build_scenario(sys.argv[4]);generate(scenario,fresh)
for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
    assert (attempt/name).read_bytes()==(fresh/name).read_bytes(), 'regenerated input differs: '+name
before=(attempt/'verification.json').read_bytes()
passed,result=verify(scenario,attempt)
assert passed and not result['difference_count'], 'recorded public outputs differ from reference'
assert before==(attempt/'verification.json').read_bytes(), 'replayed verification differs'
markers={name:[] for name in ('BW_READY','SCALE_RUN_START','SCALE_PASS')}
phases=[]
with (attempt/'simulation.log').open() as log:
    for line in log:
        tag=line.split(' ',1)[0]
        if tag in markers:markers[tag].append(keyvalues(line))
        if tag=='BW_PHASE':phases.append(keyvalues(line))
assert all(len(rows)==1 for rows in markers.values()), 'start/final marker count'
for rows in markers.values():
    assert rows[0]['points']==str(scenario.points) and rows[0]['groups']==str(len(scenario.groups))
start=markers['SCALE_RUN_START'][0];end=markers['SCALE_PASS'][0]
policy=json.loads((attempt/'input.json').read_text())['analysis']
fixed=policy['N']==6 and policy['K']==2
assert fixed or (policy['N']==3 and policy['K']==4), 'unrecognized recorded phase policy'
origin=int(markers['BW_READY'][0]['time_ticks']) if fixed else 0
for key,value in dict(scopes=scenario.points+len(scenario.groups),edges=scenario.clock.edges,
                      end_ticks=origin+scenario.end,basis=int(scenario.basis=='cycle'),W=scenario.width,
                      S=scenario.stride,variant=scenario.variant,waves=0).items():
    assert start[key]==str(value),('start marker',key)
assert end['end_ticks']==str(origin+scenario.end) and end['checked_raw']==str(result['checked_raw'])
if scenario.variant=='baseline':
    factor=1000000 if scenario.basis=='ns' else 500000;offset=0 if scenario.basis=='ns' else 250000
    start=(scenario.width+(policy['N']-1)*scenario.stride)*factor+offset
    confirm=start+(policy['K']-1)*scenario.stride*factor
    assert len(phases)==scenario.points+len(scenario.groups)
    cards={scenario.identity(k,i):1 if k=='point' else len(scenario.leaves[i]) for k,i in scenario.scopes()}
    for phase in phases:
        card=cards[phase['scope']]
        expected=dict(kind=2,epoch=0,episode=1,phase=1,result_seq=1,start_ticks=origin+start,confirm_ticks=origin+confirm,
                      end_ticks=origin+scenario.end,start_known=1,end_known=0,
                      start_bytes=64*scenario.clock.lt(start)*card,start_events=scenario.clock.lt(start)*card,
                      end_bytes=64*scenario.clock.edges*card,end_events=scenario.clock.edges*card,reason=2)
        for field,value in expected.items():assert phase[field]==str(value),(phase['scope'],field)
        assert abs(float(phase['delta']))<=1e-10 and abs(float(phase['rms']))<=1e-10
print(json.dumps(result,sort_keys=True))
'''


def replay(source, attempt, allow_tracer=False):
    manifest = json.loads((attempt / 'manifest.json').read_text())
    nominal = validate_manifest(manifest, allow_tracer)
    for name, expected in manifest['source_sha256'].items():
        require(sha(source / name) == expected, 'consumed source hash differs: ' + name)
    for name, expected in manifest['evidence_sha256'].items():
        require(sha(attempt / name) == expected, 'original evidence hash differs: ' + name)
    for name, expected in manifest['generated_sha256'].items():
        require(sha(attempt / name) == expected, 'generated input hash differs: ' + name)
    require(json.loads((attempt / 'input.json').read_text()) == manifest['configuration'],
            'manifest configuration differs from original input')
    with tempfile.TemporaryDirectory(prefix='bw-max-recorded-replay-') as temporary:
        root = Path(temporary)
        copied, fresh = root / 'attempt', root / 'regenerated'
        copied.mkdir()
        fresh.mkdir()
        for path in attempt.iterdir():
            if path.is_file():
                shutil.copyfile(str(path), str(copied / path.name))
        result = subprocess.run([sys.executable, '-B', '-c', REPLAY_CODE,
                                 str(source / 'tests/scale'), str(copied), str(fresh), manifest['scenario']],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        require(result.returncode == 0, 'isolated reference replay failed: ' + result.stdout)
        checked = json.loads(result.stdout.splitlines()[-1])
    require(checked == manifest['verification'], 'replayed result differs from original manifest')
    return dict(state='RECORDED_PROFILE_REPLAY_PASSED', profile=manifest['scenario'],
                nominal_profile=nominal, nominal_acceptance_passed=False, verification=checked,
                original_evidence_not_rewritten=True, independent_input_config_reference_regenerated=True,
                frozen_final_formal_stream_rechecked=True,
                baseline_phase_boundaries_independently_checked=manifest['configuration']['config']['variant'] == 'baseline')


def read_json(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=OrderedDict)


def locate_record(receipt_path, profile=None):
    receipt = read_json(receipt_path)
    require(profile is None or receipt['profile'] == profile, 'launch profile mismatch: ' + str(receipt_path))
    manifests = list(Path(receipt['output_root']).glob('runs/*/*/manifest.json'))
    require(len(manifests) == 1, 'expected exactly one original manifest: ' + str(receipt_path))
    manifest = read_json(manifests[0])
    require(manifest['scenario'] == receipt['profile'], 'manifest profile mismatch')
    return receipt, manifests[0], manifest


def campaign_records(campaign):
    records, pending = [], []
    for profile in NOMINAL:
        receipt_path = campaign / (profile + '-launch.json')
        receipt, path, manifest = locate_record(receipt_path, profile)
        state = manifest['state']
        require(state in ('COMPILE_RUNNING', 'SIMULATION_RUNNING', 'VERIFIED'),
                profile + ' is not healthy or completed: ' + state)
        if state != 'VERIFIED':
            runner = Path('/proc') / str(receipt['runner_pid']) / 'stat'
            try:
                alive = runner.read_text().split(') ', 1)[1][0] != 'Z'
            except OSError:
                alive = False
            if not alive:
                # A successful runner may exit between reading its atomic
                # manifest and /proc. Only the reread final evidence can pass.
                manifest = read_json(path)
                state = manifest['state']
                require(state == 'VERIFIED', profile + ' runner missing before verification; no completion inferred')
        records.append((receipt_path, receipt, path, manifest))
        if state != 'VERIFIED':
            pending.append(dict(profile=profile, state=state, manifest=str(path)))
        else:
            validate_manifest(manifest)
    return records, pending


def utc():
    return datetime.datetime.utcnow().isoformat() + 'Z'


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def capture(argv, cwd=None):
    return subprocess.check_output(argv, cwd=str(cwd) if cwd else None,
                                   stderr=subprocess.STDOUT, universal_newlines=True).strip()


def link_inputs(command):
    tokens = shlex.split(command)
    search = [Path(token[2:]) for token in tokens if token.startswith('-L')]
    search += [Path('/usr/lib64'), Path('/lib64')]
    result = {}
    for token in tokens:
        if token.startswith('-l') and len(token) > 2:
            candidates = [directory / ('lib' + token[2:] + suffix)
                          for directory in search for suffix in ('.so', '.a')]
            path = next((item for item in candidates if item.is_file()), None)
            require(path is not None, 'installed linker input missing: ' + token)
            result[str(path)] = sha(path)
        elif token.startswith('/') and token.endswith(('.a', '.o', '.so', '.so.1')):
            result[token] = sha(token)
    return result


def completed_files(manifest_path, manifest):
    attempt, build = manifest_path.parent, Path(manifest['compile']['cwd'])
    names = ('input.json', 'expect.cfg', 'expected.csv', 'actual.csv', 'diffs.json',
             'verification.json', 'manifest.json', 'simulation.log', 'simulation.time-v.txt',
             'input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv')
    result = {name: attempt / name for name in names}
    result.update({'compile.log': Path(manifest['compile']['log']),
                   'compile.time-v.txt': Path(manifest['compile']['time_v']),
                   'native-dependencies.d': build / 'csrc/bw_slot_settlement.d',
                   'compile-success.json': build / 'compile-success.json'})
    return result


def check_record_files(manifest, files):
    require(read_json(files['verification.json']) == manifest['verification'], 'verification JSON differs')
    require(read_json(files['diffs.json']) == [], 'recorded differences are nonempty')
    for field, name in (('input_sha256', 'input.json'), ('cfg_sha256', 'expect.cfg'),
                        ('expected_sha256', 'expected.csv')):
        require(sha(files[name]) == manifest[field], 'recorded input hash differs: ' + name)
    compile_text = files['compile.log'].read_text()
    require(not re.search(r'(?:Warning|Error)-\[', compile_text), 'compiler diagnostic requires review')
    command = manifest['compile']['command']
    require('+vpi' in command and '-debug_access' in command
            and str(Path(manifest['source_snapshot']) / 'rtl/bw_slot_settlement.c') in command,
            'native production runtime options missing')
    for stage in ('compile', 'simulation'):
        record = manifest[stage]
        require(record['state'] == 'COMPLETED' and record['returncode'] == 0, stage + ' did not complete successfully')
        match = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', files[stage + '.time-v.txt'].read_text())
        require(match and int(match.group(1)) == record['time_v_peak_rss_kib'] > 0,
                stage + ' measured peak RSS missing or inconsistent')
        require(record['observed_process_family_peak_rss_kib'] > 0, stage + ' process-family RSS missing')
    cache = read_json(files['compile-success.json'])
    digest = hashlib.sha256(json.dumps(manifest['source_sha256'], sort_keys=True).encode())
    for name in ('input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv'):
        digest.update(files[name].read_bytes())
    require(cache['result'] == manifest['compile'] and cache['digest'] == manifest['compile_digest'] == digest.hexdigest(),
            'native compile cache identity differs')
    return compile_text, cache


def audit_record(receipt_path, launcher, current_source, allow_tracer=False):
    receipt, manifest_path, manifest = locate_record(receipt_path)
    nominal = validate_manifest(manifest, allow_tracer)
    identity = receipt['identity']
    # Ordered JSON preserves the original small-preparation integer-key order.
    fingerprint = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
    require(fingerprint == receipt['complete_build_identity'], 'launch identity hash differs')
    require(sha(launcher) == receipt['launcher_sha256'], 'original launcher hash differs')
    require(manifest['source_head'] == receipt['source_head'] == '31ce03c16af62911985ee9191da51c7534396ebf',
            'frozen MAX source identity changed')
    require(manifest['source_tree'] == receipt['source_tree'], 'frozen MAX source tree changed')
    require(manifest['source_sha256'] == identity['source_sha256'] and len(identity['source_sha256']) == 26,
            'consumed source inventory differs')
    source = Path(manifest['source_snapshot'])
    for name, expected in manifest['source_sha256'].items():
        require(sha(source / name) == expected == sha(Path(receipt['source_root']) / name),
                'consumed/frozen source hash differs: ' + name)
    production = {name: value for name, value in manifest['source_sha256'].items() if name.startswith('rtl/')}
    require(len(production) == 18 and production == receipt['production_sha256']
            and receipt['production_runtime'] == '56127495f597d215003000356ac3b5387cc809a1',
            'reviewed production inventory differs')
    for name, expected in production.items():
        require(sha(current_source / name) == expected, 'current production changed: ' + name)
    original_hash = sha(manifest_path)
    replayed = replay(source, manifest_path.parent, allow_tracer)
    files = completed_files(manifest_path, manifest)
    compile_text, cache = check_record_files(manifest, files)
    build = Path(manifest['compile']['cwd'])
    for name, expected in manifest['generated_sha256'].items():
        require(sha(build / name) == expected, 'compiled generated input differs: ' + name)
    native_lines = [line for line in compile_text.splitlines()
                    if line.startswith('gcc ') and '/bw_slot_settlement.c' in line]
    require(len(native_lines) == 1, 'expected one actual native compiler command')
    native_argv = shlex.split(native_lines[0])
    native_source = str(source / 'rtl/bw_slot_settlement.c')
    require(native_source in native_argv, 'native compiler consumed a different source')
    options = [token for token in native_argv[1:] if token not in ('-c', native_source)]
    require(set(options) == set(receipt['native_dependency_command'][2:-1]) and '-O' in options,
            'actual optimized native options differ from launch dependency survey')
    query = [native_argv[0], '-M'] + options + [native_source]
    dependencies = capture(query, build)
    paths = shlex.split(dependencies.replace('\\\n', ' ').split(':', 1)[1])
    headers = {name: sha(name) for name in paths if Path(name).resolve() != Path(native_source).resolve()}
    require(len(headers) == 50 and headers == identity['native_header_sha256'],
            'actual optimized native header inventory changed')
    original_dependency = files['native-dependencies.d'].read_text()
    require(native_source in original_dependency, 'original VCS dependency source differs')
    sdk = [name for name in headers if name.endswith(('/svdpi.h', '/vpi_user.h'))]
    require(len(sdk) == 2 and all(name in original_dependency for name in sdk), 'original SDK dependencies missing')
    link_lines = [line for line in compile_text.splitlines() if line.startswith('g++ ')]
    require(len(link_lines) == 1, 'expected one original native link command')
    installed_links = link_inputs(link_lines[0])
    require(installed_links == identity['installed_native_link_input_sha256'], 'installed native link inputs changed')
    versions, tool_hashes = {}, {}
    for name, argv in (('vcs', ['vcs', '-ID']), ('gcc', ['gcc', '--version']), ('gxx', ['g++', '--version'])):
        versions[name] = capture(argv)
        require(versions[name] == identity[name], 'tool version changed: ' + name)
        executable = Path(shutil.which(argv[0])).resolve()
        tool_hashes[name] = dict(executable=str(executable), sha256=sha(executable))
    require(sha(build / 'simv') == cache['binary_sha256'], 'original simulator binary hash changed')
    expected, observed = receipt['expected_counts'], manifest['verification']
    for field, actual in (('raw_receipts_checked', 'checked_raw'), ('new_window_publications_checked', 'checked_windows'),
                          ('final_scope_rows', 'observed_scopes')):
        require(expected[field] == observed[actual], 'launch expected count differs: ' + field)
    require(sha(manifest_path) == original_hash, 'original manifest changed during audit')
    audit = dict(replayed, state='AUDITED', audited_utc=utc(), manifest=str(manifest_path),
                 complete_build_identity=receipt['complete_build_identity'], source_hash_count=26,
                 native_header_count=50, native_header_sha256=headers, actual_native_argv=native_argv,
                 full_dependency_query_argv=query, full_dependencies=dependencies,
                 native_dependencies_sha256=sha(files['native-dependencies.d']),
                 actual_link_command=link_lines[0], installed_native_link_input_sha256=installed_links,
                 native_object_sha256=sha(build / 'csrc/bw_slot_settlement.o'), simulator_sha256=cache['binary_sha256'],
                 all_recorded_source_header_link_hashes_unchanged=True, tool_versions_match_launch=True,
                 tool_versions=versions, postrun_tool_executable_sha256=tool_hashes,
                 postrun_tool_hashes_are_supplemental_not_prelaunch_claims=True,
                 compile_peak_kib=manifest['compile']['time_v_peak_rss_kib'],
                 simulation_peak_kib=manifest['simulation']['time_v_peak_rss_kib'])
    return receipt, manifest, files, audit


def compress(path, source):
    path.parent.mkdir(parents=True, exist_ok=True)
    with source.open('rb') as raw, path.open('wb') as stream:
        with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0, compresslevel=9) as zipped:
            shutil.copyfileobj(raw, zipped, 1048576)
    return dict(gzip_file=path.name, gzip_bytes=path.stat().st_size, gzip_sha256=sha(path),
                uncompressed_bytes=source.stat().st_size, uncompressed_sha256=sha(source))


def unpack(directory, name, entry, destination):
    relative = Path(name)
    require(not relative.is_absolute() and '..' not in relative.parts, 'unsafe archived path')
    compressed = directory / entry['gzip_file']
    require(sha(compressed) == entry['gzip_sha256'] and compressed.stat().st_size == entry['gzip_bytes'],
            'compressed archive hash differs: ' + name)
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(str(compressed), 'rb') as raw, target.open('wb') as stream:
        shutil.copyfileobj(raw, stream, 1048576)
    require(sha(target) == entry['uncompressed_sha256'] and target.stat().st_size == entry['uncompressed_bytes'],
            'uncompressed archive hash differs: ' + name)
    return target


def verify_archive(directory, current_source=None):
    proof = read_json(directory / 'proof.json')
    require(proof['archive_format'] == 1, 'unknown archive format')
    full = proof['status'] == 'FULL_NOMINAL_CAMPAIGN_AUDITED'
    require(full or proof['status'] == 'RECORDED_PROFILE_AUDITED', 'archive has no completed audit status')
    require(proof['nominal_acceptance_passed'] == full and proof['independent_merger_and_final_review_required'],
            'archive acceptance/review claim differs')
    require(set(proof['profiles']) == set(NOMINAL) if full else len(proof['profiles']) == 1,
            'archive profile coverage differs')
    actual_files = {str(path.relative_to(directory)) for path in directory.rglob('*') if path.is_file()}
    require(actual_files == set(proof['archive_files']) | {'proof.json'}, 'archive file inventory differs')
    for name, record in proof['archive_files'].items():
        require(sha(directory / name) == record['sha256'] and (directory / name).stat().st_size == record['bytes'],
                'archived evidence hash differs: ' + name)
    snapshot = read_json(directory / 'source/source-index.json')
    require(len(snapshot['files']) == 26 and snapshot['source_head'] == proof['source_head']
            and snapshot['source_tree'] == proof['source_tree'], 'archived consumed source inventory differs')
    require(len(proof['production_sha256']) == 18
            and proof['production_runtime'] == '56127495f597d215003000356ac3b5387cc809a1',
            'archived production inventory differs')
    totals = {}
    with tempfile.TemporaryDirectory(prefix='bw-max-portable-verify-') as temporary:
        root = Path(temporary)
        source = root / 'source'
        for name, entry in snapshot['files'].items():
            target = unpack(directory / 'source', name, entry, source)
            if name.startswith('rtl/'):
                require(sha(target) == proof['production_sha256'][name], 'production source hash differs')
                if current_source:
                    require(sha(current_source / name) == sha(target), 'current production source differs: ' + name)
        for profile, record in proof['profiles'].items():
            archived = directory / profile
            bundle = read_json(archived / 'bundle.json')
            attempt = root / profile
            files = {name: unpack(archived, name, entry, attempt) for name, entry in bundle['files'].items()}
            manifest, receipt, audit = read_json(files['manifest.json']), read_json(archived / 'launch.json'), read_json(archived / 'audit.json')
            require(bundle['scenario'] == manifest['scenario'] == receipt['profile'] == profile, 'archived profile identity differs')
            require(manifest['source_head'] == receipt['source_head'] == proof['source_head']
                    and manifest['source_tree'] == receipt['source_tree'] == proof['source_tree'], 'archived source identity differs')
            require(manifest['source_sha256'] == receipt['identity']['source_sha256']
                    == {name: entry['uncompressed_sha256'] for name, entry in snapshot['files'].items()},
                    'archived source hashes differ')
            require(receipt['production_sha256'] == proof['production_sha256'], 'archived production hashes differ')
            require(hashlib.sha256(json.dumps(receipt['identity']).encode()).hexdigest()
                    == receipt['complete_build_identity'] == record['complete_build_identity'] == audit['complete_build_identity'],
                    'archived launch identity differs')
            require(receipt['launcher_sha256'] == sha(directory / 'launch-recipe.py'), 'archived original launcher differs')
            compile_text, cache = check_record_files(manifest, files)
            require(audit['state'] == 'AUDITED' and audit['original_evidence_not_rewritten']
                    and audit['all_recorded_source_header_link_hashes_unchanged'] and audit['tool_versions_match_launch'],
                    'independent native/source audit is missing')
            headers = receipt['identity']['native_header_sha256']
            require(len(headers) == audit['native_header_count'] == 50 and headers == audit['native_header_sha256'],
                    'archived native header inventory differs')
            actual_native = next((shlex.split(line) for line in compile_text.splitlines()
                                  if line.startswith('gcc ') and '/bw_slot_settlement.c' in line), None)
            require(actual_native == audit['actual_native_argv'] and '-O' in actual_native,
                    'archived actual native options differ')
            require(audit['full_dependency_query_argv'] == [actual_native[0], '-M']
                    + [token for token in actual_native[1:] if token != '-c'], 'archived native dependency query differs')
            dependencies = shlex.split(audit['full_dependencies'].replace('\\\n', ' ').split(':', 1)[1])
            native_source = str(Path(manifest['source_snapshot']) / 'rtl/bw_slot_settlement.c')
            require(set(dependencies) - {native_source} == set(headers), 'archived full native dependencies differ')
            original_dependency = files['native-dependencies.d'].read_text()
            require(sha(files['native-dependencies.d']) == audit['native_dependencies_sha256']
                    and native_source in original_dependency, 'archived original VCS dependency differs')
            require(all(name in original_dependency for name in headers if name.endswith(('/svdpi.h', '/vpi_user.h'))),
                    'archived original SDK dependency missing')
            require(audit['installed_native_link_input_sha256'] == receipt['identity']['installed_native_link_input_sha256']
                    and audit['actual_link_command'] in compile_text, 'archived native link evidence differs')
            require(cache['binary_sha256'] == audit['simulator_sha256'], 'archived simulator identity differs')
            for name in ('vcs', 'gcc', 'gxx'):
                require(audit['tool_versions'][name] == receipt['identity'][name], 'archived tool version differs')
            for name in ('compile', 'simulation'):
                require(manifest[name]['time_v_peak_rss_kib'] == audit[name + '_peak_kib'] == record[name + '_peak_kib'],
                        'archived RSS differs')
            replayed = replay(source, attempt, not full)
            require(replayed['verification'] == record['verification'] == audit['verification'], 'archived final verification differs')
            for key in ('checked_raw', 'checked_windows', 'episode_records', 'phase_records', 'difference_count'):
                totals[key] = totals.get(key, 0) + replayed['verification'][key]
    require(totals == proof['totals'], 'archived campaign totals differ')
    if full:
        require(totals['checked_raw'] == 6553600000 and totals['checked_windows'] == 327639039
                and totals['episode_records'] == 81921 and totals['difference_count'] == 0,
                'fixed full nominal totals differ')
    return dict(state='PORTABLE_ARCHIVE_VERIFIED', archive_status=proof['status'],
                nominal_acceptance_passed=full, profiles=list(proof['profiles']), totals=totals)


def pack_records(records, launcher, current_source, output, full_campaign=False, supplemental=None):
    require(not output.exists(), 'archive destination already exists; verify it or choose a fresh path')
    for receipt_path in records:
        receipt, _, manifest = locate_record(receipt_path)
        protected = (receipt_path.parent.resolve(), Path(receipt['source_root']).resolve(),
                     Path(receipt['output_root']).resolve(), Path(manifest['source_snapshot']).resolve())
        require(all(output != parent and parent not in output.parents for parent in protected),
                'archive must be outside active/frozen inputs')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.' + output.name + '-unaccepted-', dir=str(output.parent)) as temporary:
        stage = Path(temporary) / 'archive'
        stage.mkdir()
        proof = dict(archive_format=1, created_utc=utc(), profiles={}, totals={}, archive_files={},
                     status='FULL_NOMINAL_CAMPAIGN_AUDITED' if full_campaign else 'RECORDED_PROFILE_AUDITED',
                     nominal_acceptance_passed=full_campaign,
                     independent_merger_and_final_review_required=True)
        source_index = None
        for receipt_path in records:
            receipt, manifest, files, audit = audit_record(receipt_path, launcher, current_source, not full_campaign)
            source = Path(manifest['source_snapshot'])
            if source_index is None:
                source_index = dict(source_head=manifest['source_head'], source_tree=manifest['source_tree'], files={})
                for name, expected in manifest['source_sha256'].items():
                    entry = compress(stage / 'source' / (name + '.gz'), source / name)
                    entry['gzip_file'] = name + '.gz'
                    source_index['files'][name] = entry
                save(stage / 'source/source-index.json', source_index)
                proof.update(source_head=manifest['source_head'], source_tree=manifest['source_tree'],
                             production_runtime=receipt['production_runtime'], production_sha256=receipt['production_sha256'])
            require(source_index['source_head'] == manifest['source_head']
                    and {name: entry['uncompressed_sha256'] for name, entry in source_index['files'].items()}
                    == manifest['source_sha256'], 'campaign consumed different sources')
            profile = manifest['scenario']
            directory = stage / profile
            directory.mkdir()
            bundle = dict(scenario=profile, original_manifest=str(files['manifest.json']), files={})
            for name, path in files.items():
                bundle['files'][name] = compress(directory / (name + '.gz'), path)
                bundle['files'][name]['original_path'] = str(path)
            save(directory / 'bundle.json', bundle)
            shutil.copyfile(str(receipt_path), str(directory / 'launch.json'))
            save(directory / 'audit.json', audit)
            proof['profiles'][profile] = dict(verification=audit['verification'], complete_build_identity=receipt['complete_build_identity'],
                                             compile_peak_kib=audit['compile_peak_kib'], simulation_peak_kib=audit['simulation_peak_kib'])
            for key in ('checked_raw', 'checked_windows', 'episode_records', 'phase_records', 'difference_count'):
                proof['totals'][key] = proof['totals'].get(key, 0) + audit['verification'][key]
        require(not full_campaign or set(proof['profiles']) == set(NOMINAL), 'all four nominal profiles are required')
        shutil.copyfile(str(launcher), str(stage / 'launch-recipe.py'))
        shutil.copyfile(str(Path(__file__).resolve()), str(stage / 'verify.py'))
        for name, path in (supplemental or {}).items():
            target = stage / 'campaign' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(str(path), str(target))
        proof['archive_files'] = {str(path.relative_to(stage)): dict(sha256=sha(path), bytes=path.stat().st_size)
                                  for path in sorted(stage.rglob('*')) if path.is_file()}
        save(stage / 'proof.json', proof)
        verify_archive(stage, current_source)
        stage.rename(output)
    return dict(state=proof['status'], nominal_acceptance_passed=proof['nominal_acceptance_passed'],
                archive=str(output), profiles=list(proof['profiles']), totals=proof['totals'])


def qualification(args, watch=False):
    campaign, output = args.campaign.resolve(), args.output.resolve()
    current_source, launcher = args.current_source.resolve(), args.launcher.resolve()
    require(not output.exists(), 'archive destination already exists; use verify to inspect it')
    previous_state = None
    while True:
        records, pending = campaign_records(campaign)
        protected = [campaign] + [Path(receipt['source_root']).resolve() for _, receipt, _, _ in records]
        for path in [output] + ([args.status.resolve()] if watch else []):
            require(all(path != parent and parent not in path.parents for parent in protected),
                    'qualification output must be outside active/frozen inputs')
        if watch:
            args.status_safe = True
        for _, receipt, _, _ in records:
            for name, expected in receipt['production_sha256'].items():
                require(sha(current_source / name) == expected, 'current production changed during wait: ' + name)
        status = dict(checked_utc=utc(), workflow_pid=os.getpid(), nominal_acceptance_passed=False,
                      ticket_complete=False, independent_merger_and_final_review_required=True,
                      state='PENDING_FULL_SIMULATIONS' if pending else 'AUDITING_AND_PACKING_ALL_FOUR',
                      pending=pending, original_manifests=[str(path) for _, _, path, _ in records],
                      archive=str(output))
        if watch:
            save(args.status.resolve(), status)
        if pending:
            if previous_state != status['state'] or not watch:
                print(json.dumps(status, sort_keys=True), flush=True)
            if not watch:
                return status, 2
            previous_state = status['state']
            time.sleep(args.poll_seconds)
            continue
        print(json.dumps(status, sort_keys=True), flush=True)
        supplemental = {name: campaign / name for name in ('admission.json', 'campaign-launch.json',
                        'monitor-status.json', 'monitor-timeline.jsonl') if (campaign / name).is_file()}
        if args.monitor:
            supplemental['original-monitor.py'] = args.monitor.resolve()
        result = pack_records([path for path, _, _, _ in records], launcher, current_source, output,
                              full_campaign=True, supplemental=supplemental)
        if watch:
            save(args.status.resolve(), dict(status, state='ARCHIVE_READY_FOR_INDEPENDENT_REVIEW',
                                             checked_utc=utc(), nominal_acceptance_passed=True, archive_result=result))
        return result, 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command')
    recorded = commands.add_parser('replay', help='Recheck a recorded profile in an isolated temporary directory')
    recorded.add_argument('--source', type=Path, required=True)
    recorded.add_argument('--attempt', type=Path, required=True)
    recorded.add_argument('--allow-tracer', action='store_true')
    for name in ('archive', 'watch'):
        archive = commands.add_parser(name, help='Qualify all four actual nominal profiles' + (' after waiting' if name == 'watch' else ' once'))
        archive.add_argument('--campaign', type=Path, required=True)
        archive.add_argument('--output', type=Path, required=True)
        archive.add_argument('--launcher', type=Path, required=True)
        archive.add_argument('--current-source', type=Path, required=True)
        archive.add_argument('--monitor', type=Path)
        if name == 'watch':
            archive.add_argument('--status', type=Path, required=True)
            archive.add_argument('--poll-seconds', type=int, choices=range(1, 61), default=30, metavar='1..60')
    audit = commands.add_parser('audit', help='Audit and preserve one completed recorded profile; never accepts the full campaign')
    audit.add_argument('--receipt', type=Path, required=True)
    audit.add_argument('--launcher', type=Path, required=True)
    audit.add_argument('--current-source', type=Path, required=True)
    audit.add_argument('--output', type=Path, required=True)
    audit.add_argument('--allow-tracer', action='store_true')
    verify = commands.add_parser('verify', help='Verify a portable archive without original paths, VCS, or SDKs')
    verify.add_argument('directory', type=Path)
    verify.add_argument('--current-source', type=Path)
    args = parser.parse_args()
    args.status_safe = False
    try:
        if args.command == 'replay':
            result = replay(args.source.resolve(), args.attempt.resolve(), args.allow_tracer)
        elif args.command == 'audit':
            _, _, manifest = locate_record(args.receipt)
            validate_manifest(manifest, args.allow_tracer)
            result = pack_records([args.receipt.resolve()], args.launcher.resolve(), args.current_source.resolve(),
                                  args.output.resolve())
        elif args.command == 'verify':
            result = verify_archive(args.directory.resolve(), args.current_source.resolve() if args.current_source else None)
        elif args.command in ('archive', 'watch'):
            result, code = qualification(args, args.command == 'watch')
            if code:
                return code
        else:
            raise ValueError('a command is required')
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception as error:
        if args.command == 'watch' and args.status_safe:
            save(args.status.resolve(), dict(state='QUALIFICATION_REJECTED', checked_utc=utc(), workflow_pid=os.getpid(),
                                             nominal_acceptance_passed=False, ticket_complete=False,
                                             error=type(error).__name__ + ': ' + str(error)))
        print('QUALIFICATION_REJECTED: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
