#!/usr/bin/env python3
"""COMMON-only queue; explicit root admission and closed blocker29 are required."""
import argparse
import datetime
import fcntl
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import time
import traceback

BASE = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-campaign')
LAUNCHER = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-launch.py')
AUDITOR = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-audit.py')
PROFILES = ['history-common-ns-short-dense', 'history-common-cycle-short-dense',
            'history-common-ns-long-dense', 'history-common-cycle-long-dense',
            'history-common-ns-control-clock', 'history-common-cycle-control-clock']


def now():
    return datetime.datetime.utcnow().isoformat() + 'Z'


def save(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def live(pid):
    try:
        state = pathlib.Path('/proc/{}/stat'.format(pid)).read_text().rsplit(') ', 1)[1].split()[0]
        return state != 'Z'
    except FileNotFoundError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--common-admitted', action='store_true')
    args = parser.parse_args()
    plan = dict(state='PREPARED_NOT_LAUNCHED', source_head='04ce34a85e45dab273a650e2e1131410f56885e8',
                production_runtime='56127495f597d215003000356ac3b5387cc809a1',
                concurrency_cap=2, maximum_history_concurrency=0, profiles=PROFILES,
                gate='explicit root flag plus live GitHub blocker29 CLOSED; no nominal work starts during preparation',
                future_command=[sys.executable, '-B', str(pathlib.Path(__file__).resolve()), '--common-admitted'])
    if not args.common_admitted:
        save(BASE / 'common-scheduler-plan.json', plan)
        print(json.dumps(plan))
        return 0
    blocker = json.loads(subprocess.check_output(['gh', 'issue', 'view', '29', '--repo',
                                                 'MakeReadUnique/bw_mon', '--json', 'state,url']))
    if blocker['state'] != 'CLOSED':
        parser.error('current-source common29 has not closed; no nominal launch')
    lock = (BASE / 'common-scheduler.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    spec = importlib.util.spec_from_file_location('history_audit', str(AUDITOR))
    auditor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(auditor)
    save(BASE / 'common-scheduler-launch.json', dict(plan, state='ADMITTED_RUNNING', pid=os.getpid(),
                                                    started_utc=now(), blocker=blocker))
    completed = set()
    failures = {}
    while True:
        rows = {}
        active = []
        for profile in PROFILES:
            receipt = json.loads((BASE / (profile + '-launch.json')).read_text())
            if not receipt.get('runner_pid'):
                rows[profile] = dict(state='QUEUED')
                continue
            root = pathlib.Path(receipt['output_root'])
            manifests = list(root.glob('runs/*/*/manifest.json'))
            if len(manifests) > 1:
                failures[profile] = 'unexpected multiple attempts'
            manifest_path = manifests[0] if manifests else None
            manifest = json.loads(manifest_path.read_text()) if manifest_path else {}
            state = manifest.get('state', 'STARTING')
            rows[profile] = dict(state=state, runner_pid=receipt['runner_pid'],
                                 manifest=str(manifest_path) if manifest_path else None)
            if state == 'VERIFIED':
                if profile not in completed:
                    try:
                        auditor.audit(profile)
                        completed.add(profile)
                    except Exception:
                        failures[profile] = traceback.format_exc()
            elif state.endswith('FAILED') or not live(receipt['runner_pid']):
                failures[profile] = 'runner stopped without verified result: ' + state
            else:
                active.append(profile)
        stop = BASE / 'common-admission-stop.json'
        admission_stopped = stop.exists() or bool(failures)
        if not admission_stopped:
            for profile in PROFILES:
                if len(active) >= 2:
                    break
                if rows[profile]['state'] != 'QUEUED':
                    continue
                subprocess.run([sys.executable, '-B', str(LAUNCHER), profile,
                                '--launch', '--nominal-admitted'], check=True)
                active.append(profile)
                rows[profile]['state'] = 'LAUNCHED'
        state = ('ADMISSION_STOPPED_FAILURE' if failures else
                 'ADMISSION_STOPPED_OPERATOR' if stop.exists() else
                 'ALL_SIX_COMMON_AUDITED' if len(completed) == 6 else 'RUNNING')
        save(BASE / 'common-scheduler-status.json', dict(state=state, updated_utc=now(),
                                                         concurrency_cap=2, maximum_history_concurrency=0,
                                                         active_profiles=active, audited_profiles=sorted(completed),
                                                         failures=failures, profiles=rows))
        if len(completed) == 6:
            return 0
        if admission_stopped and not active:
            return 1 if failures else 0
        time.sleep(30)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        save(BASE / 'common-scheduler-error.json', dict(state='ADMISSION_STOPPED_SCHEDULER_ERROR',
                                                        time_utc=now(), traceback=traceback.format_exc()))
        raise
