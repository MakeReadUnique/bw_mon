#!/usr/bin/env python3
"""Formal joint default-phase/5% product campaign (ticket 58).

One cold, serial chain: acquire the shared advisory lock, remove every
campaign top's build cache, compile and run the fixed four-input program plus
the mapped control/aspect cases through the unchanged tests/run.py entry,
verify each family with the existing independent joint checkers, assemble the
reviewable results table, record staged timings and clean up. Waiting counts
against the single 900 s budget; no budget restart, no sweep, no gate change.
"""
import argparse
from datetime import datetime
import fcntl
import hashlib
import importlib.util
import io
import json
import os
import re
import resource
import signal
import shutil
import subprocess
import sys
import threading
import time
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import aspects  # noqa: E402
import joint  # noqa: E402

BUDGET_SECONDS = 900


def stage_summary(commands):
    """Sum recorded seconds per stage (compile/simulation/verify/prepare)."""
    summary = {}
    for entry in commands:
        summary[entry['stage']] = summary.get(entry['stage'], 0.0) + \
            entry.get('seconds', 0.0)
    return summary


def campaign_total_seconds(report):
    """Total wall time: every measured phase including lock wait and cleanup."""
    total = (report.get('lock_wait_seconds', 0.0) +
             report.get('preparation_seconds', 0.0) +
             report.get('table_seconds', 0.0) +
             report.get('cleanup_seconds', 0.0))
    for entry in report.get('commands', []):
        total += entry.get('seconds', 0.0)
    return total


def within_budget(report):
    return report.get('total_seconds', float('inf')) <= \
        report.get('budget_seconds', BUDGET_SECONDS)


def clamp_timeout(timeout, deadline, now):
    """A child may never run past the campaign deadline; zero means stop."""
    return max(0.0, min(timeout, deadline - now))


def aspect_passed(cases, outcomes):
    """An aspect passes only when every mapped case ran and passed."""
    return bool(cases) and all(outcomes.get(case) is True for case in cases)


def aspect_report(outcomes):
    """Criterion-four aspect statuses for the evidence table."""
    entries = []
    for aspect, cases in aspects.FIVE_PERCENT_ASPECTS.items():
        failed = [case for case in cases
                  if outcomes.get(case) is not True]
        entries.append({'aspect': aspect, 'cases': cases,
                        'status': 'PASS' if not failed
                        else 'FAILED_MISSING_CASES' if not outcomes
                        else 'FAILED:' + ','.join(failed)})
    return entries


def sha256_file(path):
    digest = hashlib.sha256()
    with open(str(path), 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 16), b''):
            digest.update(block)
    return digest.hexdigest()


def parse_case_outcomes(output):
    outcomes = {}
    for line in output.splitlines():
        match = re.match(r'^(PASS|FAIL) (\S+):', line)
        if match:
            outcomes[match.group(2)] = match.group(1) == 'PASS'
    return outcomes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--lock', required=True, type=Path)
    parser.add_argument('--budget', type=int, default=BUDGET_SECONDS)
    args = parser.parse_args()
    cases = aspects.campaign_cases()
    start = time.monotonic()
    deadline = start + args.budget
    args.evidence.mkdir(parents=True, exist_ok=True)
    report = {'started_utc': datetime.utcnow().isoformat() + 'Z',
              'budget_seconds': args.budget, 'cases': cases, 'cold': True,
              'host': list(os.uname()), 'python': sys.version,
              'commands': [], 'completed': False}
    tops = {case['top'] for case in
            json.loads((ROOT / 'tests/cases.json').read_text())
            if case['name'] in cases}
    report['tops'] = sorted(tops)
    report['source'] = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=str(ROOT)).decode().strip()
    report['dirty_source'] = bool(subprocess.check_output(
        ['git', 'status', '--porcelain'], cwd=str(ROOT)).strip())
    report['fixed_inputs'] = {
        family['id']: sha256_file(ROOT / 'tests/phase_default' /
                                  (family['id'] + '.txt'))
        for family in aspects.FIXED_ALLOCATION}
    report['fixed_configuration'] = sha256_file(
        ROOT / 'tests/phase_default/fixed.json')
    original_run = subprocess.run
    locked = False
    lock = None
    result = 1

    def timed_run(command, **kwargs):
        command = [str(item) for item in command]
        name = Path(command[0]).name
        if name == 'vcs':
            stage = 'compile'
        elif name == 'simv':
            stage = 'simulation'
        elif name == 'git':
            stage = 'prepare'
        else:
            stage = 'verify'
        entry = {'stage': stage, 'command': command,
                 'cwd': str(kwargs.get('cwd', ROOT))}
        usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
        began = time.monotonic()
        remaining = clamp_timeout(float('inf'), deadline, began)
        if remaining <= 0:
            report['commands'].append(entry)
            raise TimeoutError('campaign budget exhausted before ' + stage)
        timeout = min(float(kwargs.get('timeout', remaining)), remaining)
        if stage == 'simulation':
            popen_kwargs = dict(kwargs)
            popen_kwargs.pop('timeout', None)
            process = subprocess.Popen(command, bufsize=1, **popen_kwargs)
            expired = [False]

            def kill():
                expired[0] = True
                process.kill()
            timer = threading.Timer(timeout, kill)
            timer.daemon = True
            timer.start()
            lines = []
            ready = None
            try:
                for line in process.stdout:
                    lines.append(line)
                    if ready is None and line.startswith('BW_READY '):
                        ready = time.monotonic()
                code = process.wait()
            finally:
                timer.cancel()
            finished = time.monotonic()
            entry['initialization_observed_seconds'] = (
                None if ready is None else ready - began)
            entry['execution_after_ready_observed_seconds'] = (
                None if ready is None else finished - ready)
            entry['timed_out'] = expired[0]
            completed = subprocess.CompletedProcess(
                command, code, ''.join(lines))
            if expired[0]:
                entry['returncode'] = code
                entry['seconds'] = finished - began
                report['commands'].append(entry)
                raise TimeoutError('simulation deadline')
        else:
            kwargs['timeout'] = timeout
            completed = original_run(command, **kwargs)
        usage_after = resource.getrusage(resource.RUSAGE_CHILDREN)
        entry['child_user_seconds'] = \
            usage_after.ru_utime - usage_before.ru_utime
        entry['child_system_seconds'] = \
            usage_after.ru_stime - usage_before.ru_stime
        entry['child_peak_rss_kib_so_far'] = usage_after.ru_maxrss
        if stage == 'compile' and kwargs.get('stdout') is not None \
                and hasattr(kwargs['stdout'], 'name'):
            kwargs['stdout'].flush()
            index = sum(c['stage'] == 'compile' for c in report['commands'])
            shutil.copy2(
                kwargs['stdout'].name,
                str(args.evidence / ('compile-{}.log'.format(index))))
        entry['returncode'] = completed.returncode
        entry['seconds'] = time.monotonic() - began
        report['commands'].append(entry)
        return completed

    try:
        args.lock.parent.mkdir(parents=True, exist_ok=True)
        lock = args.lock.open('a+')

        def lock_timeout(signum, frame):
            raise TimeoutError(
                'campaign budget exhausted while waiting for serial lock')
        old_alarm = signal.signal(signal.SIGALRM, lock_timeout)
        signal.setitimer(signal.ITIMER_REAL,
                         max(.001, deadline - time.monotonic()))
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
            locked = True
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, old_alarm)
        report['lock_wait_seconds'] = time.monotonic() - start
        prepare = time.monotonic()
        for top in sorted(tops):
            build = ROOT / '.build' / 'tests' / top
            if build.exists():
                shutil.rmtree(str(build))
        spec = importlib.util.spec_from_file_location(
            'campaign58_component_entry', str(ROOT / 'tests/run.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        report['preparation_seconds'] = time.monotonic() - prepare
        subprocess.run = timed_run
        previous_argv = sys.argv
        sys.argv = [str(ROOT / 'tests/run.py'), '--no-cache'] + cases
        output_buffer = io.StringIO()
        try:
            with redirect_stdout(output_buffer):
                result = module.main()
        finally:
            sys.argv = previous_argv
            subprocess.run = original_run
        report['component_output'] = output_buffer.getvalue().splitlines()
        outcomes = parse_case_outcomes(output_buffer.getvalue())
        report['case_outcomes'] = outcomes
        counts = {stage: sum(c['stage'] == stage for c in report['commands'])
                  for stage in ('compile', 'simulation', 'verify')}
        report['stage_command_counts'] = counts
        report['completed'] = (
            result == 0 and len(outcomes) == len(cases) and
            all(outcomes.get(case) for case in cases))
        table_began = time.monotonic()
        if report['completed']:
            tables = []
            for family in aspects.FIXED_ALLOCATION:
                log_path = (ROOT / '.build' / 'tests' / 'tb_phase_fixed' /
                            (family['case'] + '.log'))
                ownership = joint.run_ownership_checker(
                    log_path, family['id'])
                tables.append(joint.build_family_table(
                    family['id'], log_path,
                    log_path.with_suffix('.verification.json'), ownership))
            report['joint_tables'] = tables
            report['aspect_entries'] = aspect_report(outcomes)
            control_ok = all(outcomes.get(case) is True
                             for row in aspects.CONTROL_TABLE
                             for case in row['cases'])
            report['control_table_verified'] = control_ok
            report['control_rows'] = [
                {'episode': row['episode'], 'phase': row['phase'],
                 'outcome': ('verified in campaign' if control_ok else
                             'NOT VERIFIED'),
                 'cases': row['cases']} for row in aspects.CONTROL_TABLE]
            report['table_differences'] = [
                difference for table in tables
                for difference in table['differences']]
            report['completed'] = (report['completed'] and control_ok and
                                  not report['table_differences'] and
                                  all(entry['status'] == 'PASS' for entry in
                                      report['aspect_entries']))
        report['table_seconds'] = time.monotonic() - table_began
    except KeyboardInterrupt:
        report['error'] = 'Interrupted by caller'
        report['interrupted'] = True
    except Exception as error:
        report['error'] = repr(error)
    finally:
        subprocess.run = original_run
        cleanup = time.monotonic()
        for top in sorted(tops):
            build = ROOT / '.build' / 'tests' / top
            if not build.exists():
                continue
            if top == 'tb_phase_fixed':
                target = args.evidence
            else:
                target = args.evidence / 'logs' / top
                target.mkdir(parents=True, exist_ok=True)
            for path in sorted(build.iterdir()):
                if path.is_file() and (path.suffix in ('.log', '.json')
                                       or path.name == 'source.sha256'):
                    shutil.copy2(str(path), str(target / path.name))
        for top in sorted(tops):
            build = ROOT / '.build' / 'tests' / top
            if build.exists():
                shutil.rmtree(str(build))
        report['cleanup_seconds'] = time.monotonic() - cleanup
        report['stage_seconds'] = stage_summary(report['commands'])
        report['total_seconds'] = campaign_total_seconds(report)
        report['child_peak_rss_kib'] = \
            resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        report['runner_peak_rss_kib'] = \
            resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        report['rss_scope'] = ('ru_maxrss of waited children and runner '
                               'separately; not summed and not simultaneous '
                               'process-tree RSS')
        report['within_budget'] = within_budget(report)
        report['passed'] = bool(report.get('completed') and
                                report['within_budget'])
        if report.get('joint_tables') is not None:
            # The reviewable table carries the final measured totals, so it
            # is rendered only after every timed phase (incl. cleanup).
            (args.evidence / 'joint-table.md').write_text(
                joint.render_markdown(report['joint_tables'],
                                      report['aspect_entries'],
                                      report['control_rows'], report))
            (args.evidence / 'joint-table.json').write_text(
                json.dumps(report['joint_tables'], indent=2) + '\n')
        (args.evidence / 'timing.json').write_text(
            json.dumps(report, indent=2) + '\n')
        if locked:
            fcntl.flock(lock, fcntl.LOCK_UN)
        if lock is not None:
            lock.close()
    print('CAMPAIGN58 {} seconds={:.3f} stages={} evidence={}'.format(
        'PASS' if report['passed'] else 'INCOMPLETE',
        report['total_seconds'], report['stage_seconds'], args.evidence))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
