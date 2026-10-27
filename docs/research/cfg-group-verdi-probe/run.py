#!/usr/bin/env python3
"""Build once, run two startup cfgs, and read actual FSDB data with Synopsys tools."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BUILD = ROOT / '.build/cfg-group-verdi-probe'
OUT = HERE / 'evidence'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd, log):
    with log.open('w') as handle:
        subprocess.run([str(x) for x in command], cwd=cwd, stdout=handle,
                       stderr=subprocess.STDOUT, check=True, timeout=120)


def main():
    # This private generated directory belongs exclusively to this probe.
    if BUILD.exists():
        shutil.rmtree(str(BUILD))
    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(exist_ok=True)
    source = HERE / 'probe.sv'
    compile_cmd = ['vcs', '-full64', '-sverilog', '-debug_access+all', '-kdb',
                   '-top', 'tb_cfg_group_probe', '-o', BUILD / 'simv', source]
    run(compile_cmd, BUILD, OUT / 'compile.log')
    assert not re.search(r'(?:Warning|Error)-\[', (OUT / 'compile.log').read_text())
    executable = BUILD / 'simv'
    binary_sha = sha(executable)
    # Hash shared objects too: the executable hash alone does not identify all code.
    payloads = [executable] + sorted(p for p in BUILD.rglob('*.so') if p.is_file())
    build_hashes = {str(p.relative_to(BUILD)): sha(p) for p in payloads}
    manifest = {'scope': 'wave-carrier feasibility only; not product acceptance',
                'source_sha256': sha(source),
                'compile_command': [str(x) for x in compile_cmd],
                'compile_count': 1, 'build_payload_sha256': build_hashes, 'runs': []}
    for case in ['first', 'second']:
        out = OUT / case
        out.mkdir(exist_ok=True)
        command = [executable, '-no_save', '+CFG=' + str(HERE / (case + '.cfg')),
                   '+FSDB=' + str(out / 'waves.fsdb')]
        before = {str(p.relative_to(BUILD)): sha(p) for p in payloads}
        assert before == build_hashes
        run(command, BUILD, out / 'run.log')
        log = (out / 'run.log').read_text()
        assert 'PROBE_PASS' in log and 'Fatal:' not in log
        mapping = dict(re.findall(r'MAP group_id=(\S+) path=(\S+)', log))
        assert set(mapping) == ({'g2'} if case == 'first' else {'g2', 'g1'})
        signals = []
        for gid, base in mapping.items():
            signals += [base + '/' + leaf for leaf in
                        ['group_id', 'active', 'bandwidth_gbps', 'result_seq',
                         'window_bytes', 'window_full', 'bytes_complete', 'probe_state']]
        report = ['fsdbreport', str(out / 'waves.fsdb'), '-nolog', '-csv',
                  '-s', *signals, '-o', str(out / 'signals.csv')]
        run(report, BUILD, out / 'fsdbreport.log')
        assert (out / 'signals.csv').stat().st_size > 0, 'FSDB report is empty'
        assert '*WARN*' not in (out / 'fsdbreport.log').read_text(), 'Missing FSDB signals'
        convert = ['fsdb2vcd', str(out / 'waves.fsdb'), '-o', str(out / 'waves.vcd')]
        run(convert, BUILD, out / 'fsdb2vcd.log')
        after = {str(p.relative_to(BUILD)): sha(p) for p in payloads}
        assert before == after == build_hashes
        (out / 'mapping.json').write_text(json.dumps(mapping, indent=2) + '\n')
        manifest['runs'].append({'case': case, 'simv_sha256_before': before['simv'],
            'simv_sha256_after': after['simv'], 'unchanged_build_payloads': True,
            'cfg_sha256': sha(HERE / (case + '.cfg')), 'mapping': mapping,
            'fsdb_sha256': sha(out / 'waves.fsdb'),
            'commands': [[str(x) for x in c] for c in [command, report, convert]]})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Compiled once; both cfg runs and FSDB extraction completed. simv=' + binary_sha)


if __name__ == '__main__':
    main()
