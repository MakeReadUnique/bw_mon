#!/usr/bin/env python3
"""Prepare one fixed history profile; nominal launch requires explicit admission."""
import argparse
import datetime
import hashlib
import json
import pathlib
import shlex
import shutil
import subprocess
import sys

BASE = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-campaign')
SOURCE = pathlib.Path('/tmp/bw-mon-spec13-resume/history31-final-frozen-04ce34a')
PLAN = pathlib.Path('/tmp/bw-mon-spec13/nominal20-newsource-revalidation-plan.json')
MILESTONE = pathlib.Path('/tmp/bw-mon-spec13-resume/review-fix-evidence/production-milestone.json')
sys.path.insert(0, str(SOURCE / 'tests/scale'))
from history import HistoryScenario, PROFILES


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def capture(command):
    return subprocess.check_output(command, cwd=str(SOURCE), universal_newlines=True,
                                   stderr=subprocess.STDOUT).strip()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def link_inputs(command):
    tokens = shlex.split(command)
    search = [pathlib.Path(t[2:]) for t in tokens if t.startswith('-L')]
    search += [pathlib.Path('/usr/lib64'), pathlib.Path('/lib64')]
    result = {}
    for token in tokens:
        if token.startswith('-l') and len(token) > 2:
            candidates = [d / ('lib' + token[2:] + suffix)
                          for d in search for suffix in ('.so', '.a')]
            found = next((p for p in candidates if p.is_file()), None)
            if found is not None:
                result[str(found)] = sha(found)
        elif token.startswith('/') and pathlib.Path(token).is_file():
            if token.endswith(('.a', '.o', '.so', '.so.1')):
                result[token] = sha(token)
    return result


def prepare(profile):
    head = capture(['git', 'rev-parse', 'HEAD'])
    if head != '04ce34a85e45dab273a650e2e1131410f56885e8' or capture(['git', 'status', '--short']):
        raise RuntimeError('immutable frozen source changed')
    scenario = HistoryScenario(profile)
    counts = dict(raw_receipts_checked=scenario.clock.edges * (scenario.points + len(scenario.groups)),
                  new_window_publications_checked=sum(scenario.window_count(k, i) for k, i in scenario.scopes()),
                  final_scope_rows=scenario.points + len(scenario.groups))
    selected = next((p for p in json.loads(PLAN.read_text())['profiles'] if p['profile'] == profile), None)
    if selected:
        for key, value in counts.items():
            if value != selected['independent_expected_counts'][key]:
                raise RuntimeError('canonical fixed count changed: ' + key)
        target = selected['input_target']
        if scenario.topology['graph_sha256'] != target['topology']['graph_sha256']:
            raise RuntimeError('canonical graph changed')
        if (scenario.width, scenario.stride, scenario.end, scenario.clock.edges) != (
                target['W'], target['S'], target['end_ticks'], target['actual_input_edges_per_scope']):
            raise RuntimeError('canonical target changed')
    else:
        selected = dict(input_target=scenario.manifest(), independent_expected_counts=counts)
    milestone = json.loads(MILESTONE.read_text())
    production = {str(p.relative_to(SOURCE)): sha(p) for p in sorted((SOURCE / 'rtl').iterdir()) if p.is_file()}
    if len(production) != 18 or production != milestone['production_sha256']:
        raise RuntimeError('production milestone mismatch')
    inventory = dict(production)
    inventory.update({str(p.relative_to(SOURCE)): sha(p) for p in sorted((SOURCE / 'tests/scale').glob('*.py'))})
    inventory['tests/scale/tb_scale_tracer.sv'] = sha(SOURCE / 'tests/scale/tb_scale_tracer.sv')

    # This seed is an actual final-source VCS compile on this same tool setup.
    # The postrun audit compares each history build's own recorded native/link commands.
    seed_log = next(pathlib.Path('/tmp/bw-mon-spec13-resume/max30-final-complete-campaign').glob(
        'max-tracer-ns-*/builds/*/compile-attempt-1/compile.log'))
    seed_lines = seed_log.read_text().splitlines()
    native_line = next(line for line in seed_lines if line.startswith('gcc ') and '/bw_slot_settlement.c' in line)
    native_tokens = shlex.split(native_line)
    native_source = next(token for token in native_tokens if token.endswith('/bw_slot_settlement.c'))
    native_options = [token for token in native_tokens[1:] if token not in ('-c', native_source)]
    dependency_command = ['gcc', '-M'] + native_options + [str(SOURCE / 'rtl/bw_slot_settlement.c')]
    dependencies = capture(dependency_command)
    paths = shlex.split(dependencies.replace('\\\n', ' ').split(':', 1)[1])
    headers = {path: sha(path) for path in paths
               if pathlib.Path(path).is_file() and pathlib.Path(path).resolve() != (SOURCE / 'rtl/bw_slot_settlement.c').resolve()}
    if len(headers) != 50 or '-O' not in native_options:
        raise RuntimeError('expected optimized native inventory of two SDK and 48 system headers')
    link_line = next(line for line in seed_lines if line.startswith('g++ '))
    installed_links = link_inputs(link_line)
    if len(installed_links) < 10:
        raise RuntimeError('incomplete installed native link inventory')
    sdk = pathlib.Path(shutil.which('vcs')).resolve().parents[1] / 'include'
    tools = {}
    for name, option in [('vcs', '-ID'), ('gcc', '--version'), ('g++', '--version')]:
        executable = pathlib.Path(shutil.which(name)).resolve()
        tools[name] = dict(executable=str(executable), sha256=sha(executable), version=capture([name, option]))
    options = ['-full64', '-sverilog', '-timescale=1ns/1fs', '+vpi', '-debug_access',
               '-CFLAGS', '-I' + str(sdk), '+incdir+<consumed RTL>', '-assert', 'svaext',
               '-top', 'tb_bw_scale', '-o', '<isolated build>/simv']
    identity = dict(source_sha256=inventory, native_header_sha256=headers,
                    actual_native_options=native_options, installed_native_link_input_sha256=installed_links,
                    tools=tools, compile_options=options, simulation_options=['-no_save'],
                    profile_input=selected['input_target'])
    identity = json.loads(json.dumps(identity))
    digest = fingerprint(identity)
    output = BASE / (profile + '-' + digest[:20])
    receipt = dict(profile=profile, state='PREPARED_NOT_LAUNCHED', source_root=str(SOURCE),
                   source_head=head, source_tree=capture(['git', 'rev-parse', 'HEAD^{tree}']),
                   production_runtime=milestone['head'], production_sha256=production,
                   complete_build_identity=digest, identity=identity, output_root=str(output),
                   expected_counts=selected['independent_expected_counts'], launcher_sha256=sha(__file__),
                   native_dependency_command=dependency_command, native_dependencies=dependencies,
                   native_seed=dict(compile_log=str(seed_log), compile_log_sha256=sha(seed_log),
                                    native_command=native_line, link_command=link_line),
                   native_dot_d_scope='VCS original dependency file excludes system headers; preserve it and the separate actual-flags full inventory.')
    return output, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', choices=list(PROFILES))
    parser.add_argument('--launch', action='store_true')
    parser.add_argument('--nominal-admitted', action='store_true')
    args = parser.parse_args()
    nominal = not PROFILES[args.profile]['tracer']
    if args.launch and nominal and not args.nominal_admitted:
        parser.error('nominal history requires explicit root admission after current common29 closes')
    output, receipt = prepare(args.profile)
    path = BASE / (args.profile + '-launch.json')
    if path.exists() and json.loads(path.read_text()).get('runner_pid'):
        raise RuntimeError('already launched; inspect existing receipt, never duplicate')
    if args.launch:
        if output.exists():
            raise RuntimeError('fresh output root already exists')
        output.mkdir(parents=True)
        command = [sys.executable, '-B', str(SOURCE / 'tests/scale/history.py'), args.profile,
                   '--force-compile', '--output-root', str(output)]
        with (output / 'runner.log').open('w') as log:
            process = subprocess.Popen(command, cwd=str(SOURCE), stdin=subprocess.DEVNULL,
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        receipt.update(argv=command, runner_pid=process.pid, state='LAUNCHED_NOT_PASSED',
                       launched_utc=datetime.datetime.utcnow().isoformat() + 'Z',
                       admission=('explicit root nominal admission required' if nominal else
                                  'root authorizes serial small public tracers; this is not nominal qualification'))
    write(path, receipt)
    print(json.dumps(dict(profile=args.profile, receipt=str(path), state=receipt['state'],
                          complete_build_identity=receipt['complete_build_identity'],
                          runner_pid=receipt.get('runner_pid'), output_root=str(output))))


if __name__ == '__main__':
    main()
