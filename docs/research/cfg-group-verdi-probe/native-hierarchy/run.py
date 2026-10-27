#!/usr/bin/env python3
"""Investigate native Group ID scopes using only a frozen input FSDB."""
import csv
import hashlib
import json
import os
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'evidence/second'
OUT = HERE / 'evidence'
WORK = HERE.parents[3] / '.build/native-hierarchy'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    original = SOURCE / 'waves.fsdb'
    before = sha(original)
    mapping = json.loads((SOURCE / 'mapping.json').read_text())
    commands = []
    env = dict(os.environ, FSDB_ENV_MAX_GLITCH_NUM='0')

    def run(cmd, name):
        commands.append([str(x) for x in cmd])
        with (OUT / (name + '.log')).open('w') as log:
            subprocess.run(commands[-1], cwd=str(WORK), env=env,
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)

    extracted = WORK / 'selected.fsdb'
    cmd = ['fsdbextract', original, '-nolog', '-seq', '-s']
    for base in mapping.values():
        cmd += [base, '-level', '0']
    cmd += ['-o', extracted]
    run(cmd, 'extract')
    current = extracted
    renamed = {}
    for index, (gid, old) in enumerate(mapping.items()):
        target = OUT / 'groups.fsdb' if index == len(mapping) - 1 else WORK / (gid + '.fsdb')
        run(['fsdbedit', current, '-rename_scope', old.lstrip('/'), gid, '-o', target],
            'rename-' + gid)
        current = target
        renamed[gid] = old.rsplit('/', 1)[0] + '/' + gid
    with (SOURCE / 'signals.csv').open(newline='') as handle:
        expected = list(csv.reader(handle))
    paths = []
    for name in expected[0][1:]:
        for gid, base in mapping.items():
            if name.startswith(base + '/'):
                paths.append(renamed[gid] + name[len(base):])
                break
        else:
            raise AssertionError('Unmapped source signal: ' + name)
    run(['fsdbreport', current, '-nolog', '-csv', '-s', *paths,
         '-o', OUT / 'signals.csv'], 'report')
    with (OUT / 'signals.csv').open(newline='') as handle:
        actual = list(csv.reader(handle))
    assert actual[0] == ['Time(1ps)'] + paths
    assert actual[1:] == expected[1:], 'A recorded signal value or timestamp changed'
    assert sha(original) == before, 'Original FSDB changed'
    (OUT / 'mapping.json').write_text(json.dumps(renamed, indent=2) + '\n')
    (OUT / 'manifest.json').write_text(json.dumps({
        'source_fsdb_sha256': before, 'source_unchanged': True,
        'derived_fsdb_sha256': sha(current), 'original_mapping': mapping,
        'derived_mapping': renamed, 'commands': commands,
        'extraction_environment': {'FSDB_ENV_MAX_GLITCH_NUM': '0'},
        'source_rows': len(expected) - 1, 'signals_checked': len(paths),
        'all_exported_timestamps_and_values_equal': True,
        'simulation_rerun': False, 'compilation': False,
        'scope': 'Selected public fields in this small probe only; no general losslessness or scale claim'
    }, indent=2) + '\n')
    print('PASS: native scope rename preserved all 16 exported public fields and timestamps')


if __name__ == '__main__':
    main()
