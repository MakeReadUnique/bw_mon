#!/usr/bin/env python3
"""Serial, budgeted acceptance stages; a timeout is an incomplete result, never PASS."""
import argparse
import datetime
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def save(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')
    temporary.replace(path)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def build_identity(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def build_artifacts(build):
    paths=[build/'simv']+sorted(p for p in (build/'simv.daidir').rglob('*') if p.is_file())
    return {str(p.relative_to(build)):sha(p) for p in paths if p.is_file()}


def capture(command):
    return subprocess.check_output(command, cwd=str(REPO), stderr=subprocess.STDOUT,
                                   universal_newlines=True, timeout=20).strip()


def _terminate_group(process):
    # The process may have exited while a descendant still owns the group.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def _group_has_live_process(pgid):
    return bool(_group_processes(pgid))


def _group_processes(pgid):
    members=[]
    for status in Path('/proc').glob('[0-9]*/stat'):
        try:
            # comm can contain spaces and parentheses; fields begin after its last ')'.
            fields = status.read_text().rsplit(')', 1)[1].split()
            if fields[0] != 'Z' and int(fields[2]) == pgid:
                members.append(dict(pid=int(status.parent.name),state=fields[0],parent=int(fields[1]),
                                    command=(status.parent/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')))
        except (OSError, ValueError, IndexError):
            continue
    return members


def execute_stage(command, directory, stage, timeout_seconds):
    directory.mkdir(parents=True, exist_ok=True)
    log = directory / (stage + '.log')
    resource = directory / (stage + '.time-v.txt')
    wrapped = ['/usr/bin/time', '-v', '-o', str(resource)] + list(command)
    result = dict(command=wrapped, cwd=str(directory), state='RUNNING',
                  timeout_seconds=max(0, timeout_seconds), started_utc=datetime.datetime.utcnow().isoformat()+'Z')
    start = time.monotonic()
    if timeout_seconds <= 0:
        result.update(state='TIMED_OUT', returncode=None, elapsed_seconds=0)
        return result
    process = None
    old_handlers = {}
    offset = 0
    def read_markers():
        nonlocal offset
        if stage != 'simulation' or not log.exists():
            return
        with log.open() as stream:
            stream.seek(offset)
            lines = stream.read()
            offset = stream.tell()
        if 'initialization_seconds' not in result and re.search(r'^(?:BW_READY(?: |$)|ACCEPTANCE_READY(?: |$))', lines, re.M):
            result['initialization_seconds'] = time.monotonic() - start
    def interrupted(signum, frame):
        raise KeyboardInterrupt('signal ' + str(signum))
    try:
        for signum in (signal.SIGTERM, signal.SIGINT):
            old_handlers[signum] = signal.signal(signum, interrupted)
        with log.open('w') as output:
            process = subprocess.Popen(wrapped, cwd=str(directory), stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            result['pid'] = process.pid
            while process.poll() is None:
                elapsed = time.monotonic() - start
                if elapsed >= timeout_seconds:
                    result['state'] = 'TIMED_OUT'
                    _terminate_group(process)
                    break
                # Fixture stage markers are flushed. Poll resolution is recorded.
                read_markers()
                time.sleep(min(0.05, timeout_seconds - elapsed))
            result['returncode'] = process.wait()
            read_markers()
    except KeyboardInterrupt:
        result['state'] = 'INTERRUPTED'
        if process is not None:
            _terminate_group(process)
            result['returncode'] = process.returncode
    finally:
        if process is not None and process.poll() is None:
            _terminate_group(process)
        # VCS can finish its main kernel just before a native helper finishes
        # shutdown. Count this drain in the stage budget, without accepting a
        # persistent orphan merely because its parent exited successfully.
        if process is not None and result['state'] == 'RUNNING':
            drain_started = time.monotonic()
            drain_deadline = min(start + timeout_seconds, drain_started + 5)
            result['descendants_at_parent_exit'] = _group_processes(process.pid)
            while _group_has_live_process(process.pid) and time.monotonic() < drain_deadline:
                time.sleep(0.02)
            result['descendant_drain_seconds'] = time.monotonic() - drain_started
        if process is not None and _group_has_live_process(process.pid):
            result['descendants_at_cleanup'] = _group_processes(process.pid)
            _terminate_group(process)
            result['descendants_terminated'] = True
            if result['state'] == 'RUNNING':
                result['state'] = 'FAILED_DESCENDANTS'
        for signum, handler in old_handlers.items():
            signal.signal(signum, handler)
    result['elapsed_seconds'] = time.monotonic() - start
    result['finished_utc'] = datetime.datetime.utcnow().isoformat()+'Z'
    if result['state'] == 'RUNNING':
        result['state'] = 'COMPLETED' if result['returncode'] == 0 else 'FAILED'
    if stage == 'simulation':
        result['marker_poll_resolution_seconds'] = 0.05
        result['simulation_after_ready_seconds'] = (result['elapsed_seconds'] - result['initialization_seconds']
                                                     if 'initialization_seconds' in result else None)
    if resource.exists():
        match = re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)', resource.read_text())
        if match:
            result['peak_rss_kib'] = int(match.group(1))
    save(directory / (stage + '.stage.json'), result)
    return result


def tool_identity():
    vcs = Path(shutil.which('vcs')).resolve()
    include = vcs.parents[1] / 'include'
    identity = {'vcs_version': capture(['vcs', '-ID']), 'python_version': sys.version,
                'gcc_version': capture(['gcc', '--version']),
                'executables': {name: {'path': str(Path(shutil.which(name)).resolve()),
                                       'sha256': sha(Path(shutil.which(name)).resolve())}
                                for name in ('vcs', 'gcc', 'g++', 'python3')}}
    native = sorted((REPO / 'rtl').glob('*.c'))
    headers = set()
    for source in native:
        deps = capture(['gcc', '-M', '-w', '-pipe', '-fPIC', '-O', '-I'+str(include), str(source)])
        headers.update(shlex.split(deps.replace('\\\n', ' ').split(':', 1)[1]))
    identity['native_headers'] = {p: sha(Path(p)) for p in sorted(headers)}
    return identity, include


def run_bounded(scenario, output, force=False):
    started = time.monotonic()
    started_utc = datetime.datetime.utcnow().isoformat()+'Z'
    budget = scenario.budget_seconds
    module = getattr(scenario, 'source_module', scenario.__class__.__module__)
    if module == '__main__':
        raise ValueError('a standalone scenario must declare source_module for replay')
    stamp = datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S%f') + '-' + str(os.getpid())
    attempt = output / 'runs' / scenario.name / stamp
    attempt.mkdir(parents=True)
    path = attempt / 'manifest.json'
    manifest = dict(schema='bw-revised-acceptance-v1', scenario=scenario.name, budget_seconds=budget,
                    state='RUNNING', checked_pass=False, configuration=scenario.manifest(), stages={},
                    started_utc=started_utc,
                    source_head=capture(['git', 'rev-parse', 'HEAD']), source_status=capture(['git', 'status', '--short']),
                    host={'uname': capture(['uname', '-a']), 'load_start': Path('/proc/loadavg').read_text().strip(),
                          'logical_cpus': os.cpu_count(), 'memory': capture(['free', '-m'])},
                    concurrency='serial; caller holds qualification lock', waveform=False)
    save(path, manifest)
    worker = [sys.executable, str(HERE / 'bounded.py'), 'worker', module, scenario.name]
    def stage(name, command, directory=attempt):
        value = execute_stage(command, directory, name, budget - (time.monotonic()-started))
        manifest['stages'][name] = value
        save(path, manifest)
        return value['state'] == 'COMPLETED'
    def finish(good, reason):
        elapsed = time.monotonic() - started
        good = bool(good and elapsed <= budget)
        manifest.update(checked_pass=good, state='VERIFIED' if good else reason,
                        elapsed_seconds=elapsed, budget_met=elapsed <= budget,
                        finished_utc=datetime.datetime.utcnow().isoformat()+'Z',
                        host_load_finish=Path('/proc/loadavg').read_text().strip())
        save(path, manifest)
        save(output / (scenario.name+'-latest.json'), {'manifest': str(path), 'checked_pass': good})
        print(('PASS ' if good else 'FAIL ') + scenario.name + ' ' + str(path), flush=True)
        return good
    if not stage('generation', worker + ['generate', str(attempt)]):
        return finish(False, 'GENERATION_INCOMPLETE')
    inputs = {p.name: sha(p) for p in sorted(attempt.iterdir()) if p.is_file() and
              p.name not in {'manifest.json', 'generation.log', 'generation.time-v.txt', 'generation.stage.json'}}
    sources = sorted(p for p in (REPO/'rtl').rglob('*') if p.is_file()) + sorted(HERE.glob('*.py'))
    sources += [Path(p) if Path(p).is_absolute() else REPO/Path(p)
                for p in getattr(scenario, 'source_files', [])]
    sources = sorted(set(sources))
    inventory = {str(p.relative_to(REPO)): sha(p) for p in sources}
    tools, include = tool_identity()
    options = ['-full64', '-sverilog', '-timescale=1ns/1fs', '+vpi', '-debug_access',
               '-CFLAGS', '-I'+str(include), '-assert', 'svaext', '-top', 'tb_bw_scale']
    options += list(getattr(scenario, 'compile_options', []))
    identity = dict(source=inventory, inputs=inputs, tools=tools, options=options)
    digest = build_identity(identity)
    build_cache = output / 'builds' / digest
    build_cache.mkdir(parents=True, exist_ok=True)
    snapshot = build_cache / 'source'
    for source in sources:
        target = snapshot / source.relative_to(REPO)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if sha(target) != inventory[str(source.relative_to(REPO))]:
                raise RuntimeError('immutable source mismatch: '+str(target))
        else:
            shutil.copyfile(str(source), str(target))
    manifest.update(source_sha256=inventory, input_sha256=inputs, build_identity=identity,
                    compile_digest=digest, source_snapshot=str(snapshot), build_cache=str(build_cache))
    verify_worker = [sys.executable, str(snapshot/'tests/scale/bounded.py'), 'worker', module, scenario.name]
    cache = build_cache / 'compile-success.json'
    valid_cache = False
    if cache.exists() and not force:
        cached = json.loads(cache.read_text())
        build=build_cache/cached.get('build_attempt','missing-immutable-attempt')
        valid_cache = (build.is_dir() and cached.get('digest') == digest and
                       cached.get('artifacts_sha256') == build_artifacts(build))
    manifest['compile_reused'] = valid_cache
    if not valid_cache:
        build=build_cache/('attempt-'+stamp)
        build.mkdir()
        manifest['build']=str(build)
        binary=build/'simv'
        for name in ('input_pkg.sv', 'checker.sv', 'tb_bw_scale.sv'):
            shutil.copyfile(str(attempt/name), str(build/name))
        rtl = snapshot / 'rtl'
        rtl_sources = sorted(rtl.glob('*.sv'), key=lambda p: (p.name != 'bw_mon_pkg.sv', p.name))
        rtl_sources += sorted(rtl.glob('*.c'))
        command = ['vcs'] + options + ['+incdir+'+str(rtl), '-o', str(binary)]
        command += list(map(str, rtl_sources)) + [str(build/name) for name in ('input_pkg.sv','checker.sv','tb_bw_scale.sv')]
        if not stage('compile', command, build):
            return finish(False, 'COMPILE_INCOMPLETE')
        if re.search(r'(?:Warning|Error)-\[', (build/'compile.log').read_text()):
            return finish(False, 'COMPILE_DIAGNOSTIC')
        receipt={'digest':digest,'build_attempt':build.name,'binary_sha256':sha(binary),
                 'artifacts_sha256':build_artifacts(build),'stage':manifest['stages']['compile']}
        save(build/'compile-success.json',receipt)
        save(cache,receipt)
    else:
        manifest['build']=str(build)
        binary=build/'simv'
        manifest['stages']['compile'] = dict(state='CACHED', elapsed_seconds=0, original=cached['stage'])
    manifest['build_receipt_sha256']=sha(build/'compile-success.json')
    args = scenario.simulation_args(attempt) if hasattr(scenario, 'simulation_args') else [
        '+VARIANT='+scenario.variant, '+ACTUAL='+str(attempt/'actual.csv'), '+BW_EXPECT='+str(attempt/'expect.cfg')]
    if not stage('simulation', ['stdbuf', '-oL', str(binary), '-no_save'] + args):
        return finish(False, 'SIMULATION_INCOMPLETE')
    if not stage('verification', verify_worker + ['verify', str(attempt)]):
        return finish(False, 'VERIFICATION_INCOMPLETE')
    manifest['verification'] = json.loads((attempt/'verification.json').read_text())
    manifest['evidence_sha256'] = {p.name: sha(p) for p in attempt.iterdir() if p.is_file() and p.name != 'manifest.json'}
    return finish(True, 'BUDGET_EXCEEDED')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('worker', choices=['worker'])
    parser.add_argument('module')
    parser.add_argument('profile')
    parser.add_argument('stage', choices=['generate','verify'])
    parser.add_argument('attempt', type=Path)
    args = parser.parse_args()
    scenario = importlib.import_module(args.module).build_scenario(args.profile)
    if args.stage == 'generate':
        if hasattr(scenario, 'generate'):
            scenario.generate(args.attempt)
        else:
            from generate import generate
            generate(scenario, args.attempt)
        return 0
    if hasattr(scenario, 'verify'):
        result = scenario.verify(args.attempt)
    else:
        from run import verify
        result = verify(scenario, args.attempt)
    return 0 if (result[0] if isinstance(result, tuple) else result) else 1


if __name__ == '__main__':
    raise SystemExit(main())
