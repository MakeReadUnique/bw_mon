#!/usr/bin/env python3
"""Stage a fixed two-job MAX history queue; never raise the admitted cap."""
import argparse
import datetime
import fcntl
import importlib.util
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import time
import traceback

BASE = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-campaign')
LAUNCHER = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-launch.py')
AUDITOR = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-audit.py')
PROFILES = ['history-max-ns-long-dense', 'history-max-cycle-long-dense',
            'history-max-ns-short-dense', 'history-max-cycle-short-dense',
            'history-max-ns-control-clock', 'history-max-cycle-control-clock']
CAP = 2
# Host queue admission reserve, never a product memory acceptance limit.
HOST_RESERVE_KIB = 3 * 1024 * 1024


def now():
    return datetime.datetime.utcnow().isoformat() + 'Z'


def save(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def mem_available():
    line = next(line for line in pathlib.Path('/proc/meminfo').read_text().splitlines()
                if line.startswith('MemAvailable:'))
    return int(line.split()[1])


def family(pid):
    records = []
    stack = [pid]
    while stack:
        current = stack.pop()
        proc = pathlib.Path('/proc') / str(current)
        try:
            status = (proc / 'status').read_text()
            fields = (proc / 'stat').read_text().rsplit(') ', 1)[1].split()
            rss = re.search(r'^VmRSS:\s+(\d+)', status, re.M)
            records.append(dict(pid=current, ppid=int(fields[1]), start_ticks=int(fields[19]),
                                state=fields[0], utime_ticks=int(fields[11]), stime_ticks=int(fields[12]),
                                rss_kib=int(rss.group(1)) if rss else 0))
            stack.extend(int(x) for x in (proc / 'task' / str(current) / 'children').read_text().split())
        except FileNotFoundError:
            pass
    return records


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def native_health(launcher, receipt, manifest):
    build = pathlib.Path(manifest['compile']['cwd'])
    consumed = pathlib.Path(manifest['source_snapshot'])
    identity = receipt['identity']
    assert manifest['source_sha256'] == identity['source_sha256']
    for name, expected in manifest['source_sha256'].items():
        assert launcher.sha(consumed / name) == expected == launcher.sha(launcher.SOURCE / name), name
    for record in identity['tools'].values():
        assert launcher.sha(record['executable']) == record['sha256']
    text = pathlib.Path(manifest['compile']['log']).read_text()
    assert manifest['compile']['state'] == 'COMPLETED' and manifest['compile']['returncode'] == 0
    assert not re.search(r'(?:Warning|Error)-\[', text)
    line = next(line for line in text.splitlines() if line.startswith('gcc ') and '/bw_slot_settlement.c' in line)
    argv = shlex.split(line)
    source = next(token for token in argv if token.endswith('/bw_slot_settlement.c'))
    options = [token for token in argv[1:] if token not in ('-c', source)]
    assert options == identity['actual_native_options'] and '-O' in options
    query = ['gcc', '-M'] + options + [source]
    dependencies = subprocess.check_output(query, cwd=str(build), universal_newlines=True)
    paths = shlex.split(dependencies.replace('\\\n', ' ').split(':', 1)[1])
    headers = {name: launcher.sha(name) for name in paths if pathlib.Path(name).resolve() != pathlib.Path(source).resolve()}
    assert len(headers) == 50 and headers == identity['native_header_sha256']
    link = next(line for line in text.splitlines() if line.startswith('g++ '))
    assert launcher.link_inputs(link) == identity['installed_native_link_input_sha256']
    cache = json.loads((build / 'compile-success.json').read_text())
    assert cache['result'] == manifest['compile'] and cache['digest'] == manifest['compile_digest']
    assert cache['binary_sha256'] == launcher.sha(build / 'simv')
    return dict(state='ACTUAL_NATIVE_BUILD_IDENTITIES_VERIFIED', recorded_utc=now(),
                native_header_count=50, full_header_sha256=headers, actual_native_argv=argv,
                full_dependency_query_argv=query, full_dependencies=dependencies,
                actual_link_command=link, installed_link_sha256=launcher.link_inputs(link),
                native_object_sha256=launcher.sha(build / 'csrc/bw_slot_settlement.o'),
                native_dependencies_sha256=launcher.sha(build / 'csrc/bw_slot_settlement.d'),
                simulator_sha256=cache['binary_sha256'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--max-admitted', action='store_true')
    args = parser.parse_args()
    if not args.max_admitted:
        parser.error('explicit root two-job MAX history admission is required')
    blocker = json.loads(subprocess.check_output(['gh', 'issue', 'view', '29', '--repo',
                                                 'MakeReadUnique/bw_mon', '--json', 'state,url']))
    assert blocker['state'] == 'CLOSED'
    lock = (BASE / 'max-scheduler.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    launcher = load_module('history_max_launch', LAUNCHER)
    auditor = load_module('history_max_audit', AUDITOR)
    save(BASE / 'max-scheduler-launch.json', dict(pid=os.getpid(), started_utc=now(), profiles=PROFILES,
                                                 family_max_concurrency_cap=CAP, common_concurrency_cap=2,
                                                 host_admission_reserve_kib=HOST_RESERVE_KIB, blocker=blocker,
                                                 source_head='04ce34a85e45dab273a650e2e1131410f56885e8',
                                                 production_runtime='56127495f597d215003000356ac3b5387cc809a1',
                                                 root_global_admission='MAX30 cap4 + MAXhistory cap2 + COMMONhistory cap2; no elapsed-time cap increase'))
    completed = set()
    failures = {}
    native = {}
    while True:
        rows = {}
        active = []
        for profile in PROFILES:
            receipt = json.loads((BASE / (profile + '-launch.json')).read_text())
            if not receipt.get('runner_pid'):
                rows[profile] = dict(state='QUEUED')
                continue
            output = pathlib.Path(receipt['output_root'])
            paths = list(output.glob('runs/*/*/manifest.json'))
            if len(paths) > 1:
                failures[profile] = 'unexpected multiple attempts'
            manifest = json.loads(paths[0].read_text()) if paths else {}
            processes = family(receipt['runner_pid'])
            row = dict(state=manifest.get('state', 'STARTING'), runner_pid=receipt['runner_pid'],
                       manifest=str(paths[0]) if paths else None, process_family=processes,
                       family_rss_kib=sum(p['rss_kib'] for p in processes), mem_available_kib=mem_available())
            log = pathlib.Path(manifest.get('simulation', manifest.get('compile', {})).get('log', '/nonexistent'))
            text = log.read_text() if log.exists() else ''
            row['markers'] = [line for line in text.splitlines()
                              if line.startswith(('BW_READY ', 'SCALE_RUN_START ', 'SCALE_PROGRESS ', 'SCALE_PASS '))]
            if re.search(r'Fatal:|Error-\[|SCALE_\w*MISMATCH|BW_CFG_WARNING', text):
                failures[profile] = 'actual fatal/error/mismatch diagnostic'
            if manifest.get('compile', {}).get('state') == 'COMPLETED' and profile not in native:
                try:
                    native[profile] = native_health(launcher, receipt, manifest)
                    save(output / 'native-build-health.json', dict(native[profile], process_family=processes,
                                                                   family_rss_kib=row['family_rss_kib'],
                                                                   mem_available_kib=mem_available()))
                except Exception:
                    failures[profile] = traceback.format_exc()
            row['native_build_verified'] = profile in native
            row['simulation_ready'] = any(line.startswith('SCALE_RUN_START ') for line in row['markers'])
            row['simulation_started'] = (row['state'] == 'SIMULATION_RUNNING' and
                                         any(p['pid'] == manifest.get('simulation', {}).get('pid') and p['state'] != 'Z'
                                             for p in processes))
            if row['state'] == 'VERIFIED':
                if profile not in completed:
                    try:
                        auditor.audit(profile)
                        completed.add(profile)
                    except Exception:
                        failures[profile] = traceback.format_exc()
            elif row['state'].endswith('FAILED') or not any(p['pid'] == receipt['runner_pid'] and p['state'] != 'Z' for p in processes):
                failures[profile] = 'runner ended without verified result: ' + row['state']
            else:
                active.append(profile)
            rows[profile] = row
        operator_stop = (BASE / 'max-admission-stop.json').exists()
        # Root explicitly accepts a checked native build and observed live simulator
        # CPU/RSS; stdout may remain buffered during finite large-topology startup.
        staged = all(rows[profile]['native_build_verified'] and rows[profile]['simulation_started'] for profile in active)
        available = mem_available()
        if not failures and not operator_stop and len(active) < CAP and staged and available >= HOST_RESERVE_KIB:
            profile = next((name for name in PROFILES if rows[name]['state'] == 'QUEUED'), None)
            if profile is not None:
                try:
                    prior = json.loads((BASE / (profile + '-launch.json')).read_text())
                    _, fresh = launcher.prepare(profile)
                    assert fresh['complete_build_identity'] == prior['complete_build_identity'], 'prepared source/native/tool/link identity drift'
                    subprocess.run([sys.executable, '-B', str(LAUNCHER), profile,
                                    '--launch', '--nominal-admitted'], check=True)
                    active.append(profile)
                    rows[profile]['state'] = 'LAUNCHED'
                except Exception:
                    failures[profile] = traceback.format_exc()
        state = ('ADMISSION_STOPPED_FAILURE' if failures else 'ADMISSION_STOPPED_OPERATOR' if operator_stop else
                 'ALL_SIX_MAX_AUDITED' if len(completed) == 6 else 'RUNNING')
        save(BASE / 'max-scheduler-status.json', dict(state=state, updated_utc=now(), family_max_concurrency_cap=CAP,
                                                     common_concurrency_cap=2, host_admission_reserve_kib=HOST_RESERVE_KIB,
                                                     mem_available_kib=mem_available(), active_profiles=active,
                                                     audited_profiles=sorted(completed), failures=failures, profiles=rows))
        if len(completed) == 6:
            return 0
        if (failures or operator_stop) and not active:
            return 1 if failures else 0
        time.sleep(20)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        save(BASE / 'max-scheduler-error.json', dict(state='ADMISSION_STOPPED_SCHEDULER_ERROR',
                                                    time_utc=now(), traceback=traceback.format_exc()))
        raise
