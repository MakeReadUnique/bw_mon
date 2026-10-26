#!/usr/bin/env python3
"""Archive only completed/audited nominal history rows; never launch a simulator."""
import datetime
import gzip
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

REPO = pathlib.Path('/tmp/bw-mon-spec13/wt-31')
BASE = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-campaign')
MAX30 = pathlib.Path('/tmp/bw-mon-spec13-resume/max30-final-complete-campaign')
DEST = REPO / 'tests/scale/history_evidence/final-campaign'
PLAN = pathlib.Path('/tmp/bw-mon-spec13/nominal20-newsource-revalidation-plan.json')
sha = lambda data: hashlib.sha256(data).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def copy(path, name, preserve=False):
    raw = path.read_bytes()
    target = DEST / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if preserve and target.exists():
        assert target.read_bytes() == raw, ('existing original artifact changed', name)
    else:
        target.write_bytes(raw)
    return dict(file=name, sha256=sha(raw), bytes=len(raw))


def archive_source(manifest):
    consumed = pathlib.Path(manifest['source_snapshot'])
    index = dict(source_head=manifest['source_head'], source_tree=manifest['source_tree'], files={})
    for name, expected in manifest['source_sha256'].items():
        raw = (consumed / name).read_bytes()
        assert sha(raw) == expected == sha((REPO / name).read_bytes())
        path = DEST / 'source' / (name + '.gz')
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            assert gzip.decompress(path.read_bytes()) == raw, name
        else:
            with path.open('wb') as stream:
                with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0, compresslevel=9) as out:
                    out.write(raw)
        index['files'][name] = dict(gzip_file=name + '.gz', gzip_sha256=sha(path.read_bytes()),
                                    uncompressed_sha256=expected, uncompressed_bytes=len(raw))
    index_path = DEST / 'source/source-index.json'
    if index_path.exists():
        assert json.loads(index_path.read_text()) == index
    else:
        save(index_path, index)
    return index


def controller(label, pid, script, files):
    proc = pathlib.Path('/proc') / str(pid)
    if not proc.exists():
        # The common queue deliberately exits after six actual audited results.
        # Its disappearance alone must never qualify any profile.
        assert label == 'common-history'
        finished = json.loads((BASE / 'common-scheduler-status.json').read_text())
        required = {name for name in finished['profiles'] if name.startswith('history-common-')}
        assert finished['state'] == 'ALL_SIX_COMMON_AUDITED'
        assert len(required) == 6 and set(finished['audited_profiles']) == required
        assert not finished['active_profiles'] and not finished['failures']
        assert all(finished['profiles'][name]['state'] == 'VERIFIED' for name in required)
        previous = json.loads((DEST / 'controller-checkpoint.json').read_text())
        observed = previous['controllers'][label]
        assert observed['pid'] == pid
        identity = (observed['previous_live_process'] if not observed['alive_at_checkpoint'] else
                    {key: observed[key] for key in ('pid', 'argv', 'start_ticks', 'cwd', 'executable')})
        result = dict(pid=pid, state='EXITED_AFTER_ALL_SIX_COMMON_AUDITED',
                      alive_at_checkpoint=False, previous_live_process=identity,
                      completion_status_file='common-scheduler-status.json',
                      process_exit_not_used_as_acceptance=True)
    else:
        fields = (proc / 'stat').read_text().rsplit(') ', 1)[1].split()
        argv = (proc / 'cmdline').read_bytes().decode().rstrip('\0').split('\0')
        status = (proc / 'status').read_text()
        assert fields[0] != 'Z' and script in argv
        assert int(re.search(r'^Uid:\s+(\d+)', status, re.M).group(1)) == os.getuid()
        result = dict(pid=pid, state=fields[0], argv=argv, cwd=os.readlink(str(proc / 'cwd')),
                      executable=os.readlink(str(proc / 'exe')), start_ticks=int(fields[19]),
                      utime_ticks=int(fields[11]), stime_ticks=int(fields[12]), alive_at_checkpoint=True)
    result.update(script=copy(pathlib.Path(script), 'controllers/' + label + '/controller.py'), files={})
    for path in files:
        result['files'][path.name] = copy(path, 'controllers/' + label + '/' + path.name)
    return result


def main():
    common = json.loads((BASE / 'common-scheduler-status.json').read_text())
    maximum = json.loads((BASE / 'max-scheduler-status.json').read_text())
    common_launch = json.loads((BASE / 'common-scheduler-launch.json').read_text())
    max_launch = json.loads((BASE / 'max-scheduler-launch.json').read_text())
    max_admission = json.loads((BASE / 'max-operator-admission.json').read_text())
    other = json.loads((MAX30 / 'monitor-status.json').read_text())
    completed = sorted(set(common['audited_profiles']) | set(maximum['audited_profiles']))
    assert completed and not common['failures'] and not maximum['failures']
    max_cap = max_admission['family_max_history_cap']
    assert common['concurrency_cap'] == 2 and maximum['family_max_concurrency_cap'] == max_cap == 3
    assert max_admission['global_heavy_root_cap'] == 7 and max_admission['host_admission_reserve_kib'] == 3145728
    assert common['state'] == 'ALL_SIX_COMMON_AUDITED' and not common['active_profiles']
    assert len(maximum['active_profiles']) <= max_cap
    assert other['active_max30'] <= 4 and other['admission']['total_heavy_cap'] == 6
    assert other['admission']['no_elapsed_auto_admission']
    plan = json.loads(PLAN.read_text())
    targets = {row['profile']: row for row in plan['profiles'] if row['ticket'] == 31}
    assert len(targets) == 12 and set(completed) <= set(targets)
    matrix = dict(status='PARTIAL_NOMINAL_CAMPAIGN', nominal_acceptance_passed=False,
                  snapshot_utc=datetime.datetime.utcnow().isoformat() + 'Z', required_profile_count=12,
                  completed_profile_count=len(completed), completed_profiles=completed,
                  pending_profiles=sorted(set(targets) - set(completed)), profiles={})
    proof = dict(status='PARTIAL_NOMINAL_CAMPAIGN', nominal_acceptance_passed=False,
                 snapshot_utc=matrix['snapshot_utc'], completed_profiles={}, required_profile_count=12,
                 completed_profile_count=len(completed), totals=dict(checked_raw=0, checked_windows=0,
                                                                     difference_count=0, episode_records=0, phase_records=0),
                 native_header_count=50, source_count=26, supplemental_files={})
    index = None
    for profile, target in targets.items():
        receipt_path = BASE / (profile + '-launch.json')
        receipt = json.loads(receipt_path.read_text())
        root = pathlib.Path(receipt['output_root'])
        paths = list(root.glob('runs/*/*/manifest.json'))
        assert len(paths) <= 1
        manifest = json.loads(paths[0].read_text()) if paths else None
        state = manifest['state'] if manifest else 'PREPARED_NOT_LAUNCHED'
        row = dict(input=target['input_target'], required_enabled_features=target['required_enabled_features'],
                   expected_counts=target['independent_expected_counts'], state=state,
                   verified=False, actual_verification=None, verified_bundle=None,
                   original_manifest=str(paths[0]) if paths else None)
        if profile in completed:
            assert manifest['state'] == 'VERIFIED' and manifest['checked_pass'] and not manifest['source_status']
            audit_path = root / 'recorded-audit.json'
            audit = json.loads(audit_path.read_text())
            assert audit['state'] == 'AUDITED' and audit['verification'] == manifest['verification']
            assert audit['source_hash_count'] == 26 and audit['native_header_count'] == 50
            assert audit['all_recorded_source_header_tool_link_hashes_unchanged']
            assert audit['independent_input_config_reference_regenerated'] and audit['frozen_final_formal_stream_rechecked']
            for name, expected in manifest['evidence_sha256'].items():
                assert sha((paths[0].parent / name).read_bytes()) == expected
            for name, expected in audit['native_header_sha256'].items():
                assert sha(pathlib.Path(name).read_bytes()) == expected
            for name, expected in audit['installed_native_link_input_sha256'].items():
                assert sha(pathlib.Path(name).read_bytes()) == expected
            build = pathlib.Path(manifest['compile']['cwd'])
            assert audit['native_dependencies_sha256'] == sha((build / 'csrc/bw_slot_settlement.d').read_bytes())
            assert audit['native_object_sha256'] == sha((build / 'csrc/bw_slot_settlement.o').read_bytes())
            assert audit['simulator_sha256'] == sha((build / 'simv').read_bytes())
            if index is None:
                index = archive_source(manifest)
                proof.update(source_head=index['source_head'], source_tree=index['source_tree'],
                             production_runtime=receipt['production_runtime'], production_sha256=receipt['production_sha256'])
            assert manifest['source_head'] == index['source_head']
            assert {k: v['uncompressed_sha256'] for k, v in index['files'].items()} == manifest['source_sha256']
            bundle_path = DEST / profile / 'bundle.json'
            if bundle_path.exists():
                bundle = json.loads(bundle_path.read_text())
                assert bundle['original_manifest'] == str(paths[0]) and bundle['source_head'] == manifest['source_head']
                for entry in bundle['files'].values():
                    compressed = (bundle_path.parent / entry['gzip_file']).read_bytes()
                    assert sha(compressed) == entry['gzip_sha256']
                    raw = gzip.decompress(compressed)
                    assert sha(raw) == entry['uncompressed_sha256']
                    assert raw == pathlib.Path(entry['original_path']).read_bytes()
            else:
                subprocess.run([sys.executable, '-B', str(REPO / 'tests/scale/evidence/package.py'),
                                str(REPO), str(paths[0]), str(DEST)], check=True)
            launch_entry = copy(receipt_path, profile + '/launch.json', preserve=True)
            audit_entry = copy(audit_path, profile + '/recorded-audit.json', preserve=True)
            proof['completed_profiles'][profile] = dict(verification=manifest['verification'],
                                                        compile_peak_kib=manifest['compile']['time_v_peak_rss_kib'],
                                                        simulation_peak_kib=manifest['simulation']['time_v_peak_rss_kib'],
                                                        launch=launch_entry, recorded_audit=audit_entry,
                                                        complete_build_identity=receipt['complete_build_identity'])
            for key in proof['totals']:
                proof['totals'][key] += manifest['verification'][key]
            row.update(state='VERIFIED_AUDITED', verified=True, actual_verification=manifest['verification'],
                       verified_bundle=profile + '/bundle.json',
                       simulation_peak_kib=manifest['simulation']['time_v_peak_rss_kib'])
        elif state == 'VERIFIED':
            row['state'] = 'VERIFIED_AWAITING_AUDIT'
        matrix['profiles'][profile] = row
    assert index is not None and len(index['files']) == 26
    assert len(completed) < 12, 'This checkpoint deliberately represents partial acceptance only.'
    common_results = REPO / 'tests/scale/evidence/final-runtime-467b722/results.json'
    reuse = json.loads(common_results.read_text())
    assert reuse['production_runtime_freeze'] == proof['production_runtime']
    assert reuse['production_sha256'] == proof['production_sha256']
    matrix['external_common29_reuse'] = dict(path='tests/scale/evidence/final-runtime-467b722/results.json',
                                            sha256=sha(common_results.read_bytes()),
                                            profiles=sorted(reuse['profiles']), production_source_matches=True,
                                            contributes_to_twelve_new_profile_count=False)
    matrix['external_max30_reuse'] = dict(state='RUNNING_NOT_YET_ACCEPTED',
                                         profiles=[row['profile'] for row in other['profiles']],
                                         contributes_to_twelve_new_profile_count=False)
    controllers = dict(snapshot_utc=matrix['snapshot_utc'], global_heavy_cap=7, common_cap=2,
                       max30_cap=4, max_history_cap=max_cap, no_elapsed_auto_increase=True,
                       no_consumed_source_edits=True, controllers={})
    controllers['controllers']['common-history'] = controller('common-history', common_launch['pid'],
        '/tmp/bw-mon-spec13-resume/history31-final-common-scheduler.py',
        [BASE / 'common-scheduler-launch.json', BASE / 'common-scheduler-status.json', BASE / 'common-operator-admission.json'])
    controllers['controllers']['max-history'] = controller('max-history', max_launch['pid'],
        '/tmp/bw-mon-spec13-resume/history31-final-max-scheduler.py',
        [BASE / 'max-scheduler-launch.json', BASE / 'max-scheduler-status.json', BASE / 'max-operator-admission.json'])
    controllers['controllers']['max30'] = controller('max30', other['monitor_pid'],
        '/tmp/bw-mon-spec13-resume/max30-monitor.py', [MAX30 / 'admission.json', MAX30 / 'monitor-status.json'])
    transition = pathlib.Path(max_admission['cap3_transition_receipt']).parent
    controllers['cap3_transition_files'] = {}
    for path in sorted(transition.iterdir()):
        if path.is_file():
            controllers['cap3_transition_files'][path.name] = copy(path, 'controllers/cap3-transition/' + path.name, preserve=True)
    previous_proof = json.loads((DEST / 'verification.json').read_text())
    for name in ('long-window-contracts', 'prior-short-bundle-hashes'):
        entry = previous_proof['supplemental_files'][name]
        assert sha((DEST / entry['file']).read_bytes()) == entry['sha256']
        proof['supplemental_files'][name] = entry
    for key, path in [('launcher', pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-launch.py')),
                      ('auditor', pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-audit.py')),
                      ('archive-checkpoint', pathlib.Path(__file__))]:
        proof['supplemental_files'][key] = copy(path, 'recipes/' + key + '.py')
    save(DEST / 'controller-checkpoint.json', controllers)
    save(DEST / 'completion-matrix.json', matrix)
    proof['matrix_sha256'] = sha((DEST / 'completion-matrix.json').read_bytes())
    proof['controller_checkpoint_sha256'] = sha((DEST / 'controller-checkpoint.json').read_bytes())
    save(DEST / 'verification.json', proof)
    print(json.dumps(dict(status=proof['status'], completed=completed, remaining=len(matrix['pending_profiles']),
                          totals=proof['totals'], matrix=str(DEST / 'completion-matrix.json'))))


if __name__ == '__main__':
    main()
