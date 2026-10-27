#!/usr/bin/env python3
"""Restore or verify recorded evidence without committing generated data again."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'b22e32e1beb704beb290e65f7af20bbe44065a34'
SCALE = 'tests/scale/revised_evidence/final-campaign'
COMPATIBILITY = 'tests/review/compatibility'
COMMON = 'tests/scale/history_evidence/final-campaign'
GROUPS = {
    'scale': [SCALE],
    'compatibility': [COMPATIBILITY],
    'common': [COMMON, 'tests/scale/evidence/final-runtime-467b722',
               'tests/scale/evidence/verify_campaign.py'],
    'waveforms': ['artifacts/acceptance', 'artifacts/review-analog'],
    'legacy-tests': ['tests/scale/evidence/maximum-final-preparation/source',
                     'tests/scale/evidence/maximum-final-preparation/max-tracer-ns',
                     'tests/scale/evidence/maximum-final-preparation/launch-recipe.py'],
}


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def check_current_source():
    expected = json.loads((ROOT / 'evidence/source-hashes.json').read_text())
    changed = [name for name, value in expected['files'].items()
               if not (ROOT / name).is_file() or digest(ROOT / name) != value]
    if changed:
        raise ValueError('Current measured inputs differ: ' + ', '.join(changed))
    print('PASS current measured source: {} files'.format(len(expected['files'])), flush=True)


def extract_snapshot(repo, revision, paths, destination):
    """Copy regular Git snapshot files, refusing to overwrite different local data."""
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    probe = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', revision + '^{commit}'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if probe.returncode:
        raise ValueError('Evidence commit is unavailable. Fetch it explicitly:\n'
                         'git fetch origin ' + revision)
    with tempfile.TemporaryDirectory(prefix='bw-evidence-stage-') as temporary:
        staging = Path(temporary)
        archive_path = staging / 'snapshot.tar'
        with archive_path.open('wb') as output:
            subprocess.check_call(['git', '-C', str(repo), 'archive', '--format=tar',
                                   revision, '--'] + list(paths), stdout=output)
        files = []
        with tarfile.open(str(archive_path)) as archive:
            for member in archive:
                relative = PurePosixPath(member.name)
                if relative.is_absolute() or '..' in relative.parts:
                    raise ValueError('Unsafe snapshot path: ' + member.name)
                if member.isdir():
                    continue
                if not member.isfile():
                    raise ValueError('Snapshot links/devices are unsupported: ' + member.name)
                if not any(member.name == p or member.name.startswith(p + '/') for p in paths):
                    raise ValueError('Unexpected snapshot member: ' + member.name)
                staged = staging / 'files' / member.name
                staged.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as source, staged.open('wb') as output:
                    shutil.copyfileobj(source, output)
                os.chmod(str(staged), member.mode & 0o777)
                files.append((relative, staged))
        if not files:
            raise ValueError('Empty evidence snapshot')
        # Check every target before writing any file; a modified local run is data.
        for relative, staged in files:
            target = destination.joinpath(*relative.parts)
            cursor = destination
            for part in relative.parts:
                cursor = cursor / part
                if cursor.is_symlink():
                    raise ValueError('Refusing destination symlink: ' + str(cursor))
                if cursor != target and cursor.exists() and not cursor.is_dir():
                    raise ValueError('Destination parent is not a directory: ' + str(cursor))
            if target.exists() and (not target.is_file() or digest(target) != digest(staged)):
                raise ValueError('Refusing to overwrite changed evidence: ' + str(target)
                                 + '\nUse --destination to restore into a separate directory.')
        for relative, staged in files:
            target = destination.joinpath(*relative.parts)
            if target.exists():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(staged), str(target))
        return len(files)


def restore(kind, destination):
    count = extract_snapshot(ROOT, SOURCE, GROUPS[kind], destination)
    print('PASS restore {}: {} files -> {}'.format(kind, count, destination), flush=True)
    return count


def verify(kind, current_source):
    if current_source:
        check_current_source()
    selected = ['compatibility', 'scale', 'waveforms', 'common'] if kind == 'all' else [kind]
    for name in selected:
        with tempfile.TemporaryDirectory(prefix='bw-evidence-verify-') as temporary:
            target = Path(temporary)
            restore(name, target)
            if name == 'waveforms':
                extract_snapshot(ROOT, SOURCE, ['tests/acceptance', 'rtl'], target)
            if name == 'scale':
                commands = [[sys.executable, str(target / SCALE / 'verify.py'),
                             'verify', str(target / SCALE)]]
            elif name == 'compatibility':
                command = [sys.executable, str(target / COMPATIBILITY / 'verify.py')]
                if current_source:
                    command += ['--current-source', '--source-root', str(ROOT)]
                commands = [command]
            elif name == 'waveforms':
                commands = [[sys.executable, str(target / 'tests/acceptance/audit.py')],
                            [sys.executable, str(target / 'artifacts/review-analog/verify.py')]]
            else:
                commands = [[sys.executable, str(target / COMMON / 'verify.py')],
                            [sys.executable, str(target / 'tests/scale/evidence/final-runtime-467b722/verify.py')]]
            for command in commands:
                subprocess.check_call(command, cwd=str(target))
            print('PASS recorded evidence: ' + name, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command')
    unpack = commands.add_parser('restore', help='restore ignored local files from the fixed Git commit')
    unpack.add_argument('kind', choices=sorted(GROUPS))
    unpack.add_argument('--destination', type=Path, default=ROOT)
    check = commands.add_parser('verify', help='replay records in a temporary directory; no simulator')
    check.add_argument('kind', choices=['all', 'scale', 'compatibility', 'waveforms', 'common'])
    check.add_argument('--current-source', action='store_true')
    commands.add_parser('check-source', help='compare current inputs with the measured source hashes')
    args = parser.parse_args()
    try:
        if args.command == 'restore':
            restore(args.kind, args.destination.resolve())
        elif args.command == 'verify':
            verify(args.kind, args.current_source)
        elif args.command == 'check-source':
            check_current_source()
        else:
            parser.error('choose restore, verify or check-source')
    except (ValueError, OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        parser.exit(1, 'FAIL ' + str(error) + '\n')


if __name__ == '__main__':
    main()
