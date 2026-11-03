#!/usr/bin/env python3
"""Fresh, independently checked FSDBs for the focused issue 61 review.

Reuses the unchanged public-input fixtures and their existing oracles. Human
acceptance is deliberately not inferred from successful simulation or capture.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/acceptance'))
from build import prepare, receipt  # noqa: E402


def run(command, directory, log):
    with log.open('w') as output:
        subprocess.run([str(item) for item in command], cwd=str(directory),
                       stdout=output, stderr=subprocess.STDOUT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.build/verdi61')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = sorted((ROOT / 'rtl').glob('*.sv'),
                     key=lambda path: (path.name != 'bw_mon_pkg.sv', path.name))
    sources += sorted((ROOT / 'rtl').glob('*.c'))
    sources += [ROOT / 'tests/tb_checker_default.sv',
                ROOT / 'tests/verdi61/dump.sv']
    build, snapshot, compile_command, fingerprint, flags = prepare(
        ROOT, 'tb_checker_default', sources)
    run(compile_command, build, out / 'compile.log')
    assert not re.search(r'(?:Warning|Error)-\[',
                         (out / 'compile.log').read_text())
    for mode in ['constant', 'alternating']:
        scene = out / mode
        scene.mkdir(exist_ok=True)
        native = receipt(ROOT, scene, build, snapshot, compile_command,
                         fingerprint, flags)
        command = [build / 'simv', '-no_save', '+FSDB=' + str(scene / 'waves.fsdb')]
        if mode == 'alternating':
            command.append('+ALTERNATE')
        run(command, build, scene / 'run.log')
        log = (scene / 'run.log').read_text()
        assert 'TB_PASS checker_default' in log and 'Fatal:' not in log
        verify = [sys.executable, ROOT / 'tests/checker_default/check.py',
                  scene / 'run.log', mode]
        run(verify, ROOT, scene / 'verify.log')
        checks = [dict(re.findall(r'(\w+)=([^ ]+)', line))
                  for line in log.splitlines()
                  if line.startswith('BW_DEFAULT_CHECK ')]
        manifest = {
            'mode': mode, 'compile': compile_command, 'run': command,
            'verify': verify, 'runtime_evidence': native,
            'fsdb_sha256': hashlib.sha256((scene / 'waves.fsdb').read_bytes()).hexdigest(),
            'automatic': 'PASS', 'human_review': 'PENDING',
            'default_checks': checks,
            'review_tool_sha256': {
                str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/checker_default/check.py']
            },
        }
        (scene / 'commands.json').write_text(
            json.dumps(manifest, indent=2, default=str) + '\n')
        print('PASS', mode, 'five independently checked point/group results', flush=True)


if __name__ == '__main__':
    main()
