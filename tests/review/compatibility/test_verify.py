#!/usr/bin/env python3
"""Portable recorded-data audit, including missing proof with consistent hashes."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def unpack(raw):
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
        return {m.name:archive.extractfile(m).read() for m in archive.getmembers()}


def pack(files):
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode='w:gz') as archive:
        for name, raw in sorted(files.items()):
            info = tarfile.TarInfo(name);info.size = len(raw);info.mtime = 0
            archive.addfile(info, io.BytesIO(raw))
    return out.getvalue()


class PortableCompatibility(unittest.TestCase):
    def execute(self, *args):
        env = dict(os.environ, PATH='/no-simulator-or-git-on-this-path')
        return subprocess.run([sys.executable, str(HERE/'verify.py')]+list(args),
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              universal_newlines=True, env=env)

    def test_original_and_current_compiled_source_need_no_simulator(self):
        result = self.execute('--current-source')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('427 components; 42 scenes; 672 equal public CSVs', result.stdout)

    def test_consistently_rehashed_missing_or_changed_proof_is_rejected(self):
        original = unpack((HERE/'proof.tar.gz').read_bytes())
        for mutation in ('missing_component', 'missing_scope_csv', 'changed_historical_csv', 'removed_phase_packets', 'variation_after_summary'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                folder = Path(temporary)
                files = dict(original)
                proof = json.loads((HERE/'verification.json').read_text())
                if mutation == 'missing_component':
                    files.pop('component-records/tb_numeric_arithmetic/numeric_arithmetic_known.log')
                elif mutation == 'missing_scope_csv':
                    files.pop('fresh/steady_ns/p0.csv')
                elif mutation == 'changed_historical_csv':
                    name = 'historical/steady_ns/trace.tar.gz'
                    trace = unpack(files[name])
                    trace['p0.csv'] = trace['p0.csv'].replace(b',64,', b',65,', 1)
                    files[name] = pack(trace)
                    hashes = json.loads(files['campaign/historical-assets-before.json'].decode())
                    hashes['steady_ns/trace.tar.gz'] = digest(files[name])
                    files['campaign/historical-assets-before.json'] = json.dumps(hashes).encode()
                elif mutation == 'variation_after_summary':
                    name = 'fresh/steady_ns/run.log'
                    lines = files[name].splitlines(True)
                    index = next(i for i,line in enumerate(lines) if line.startswith(b'BW_VARIATION '))
                    moved = lines.pop(index)
                    files[name] = b''.join(lines)+moved
                else:
                    name = 'fresh/steady_ns/run.log'
                    files[name] = b''.join(line for line in files[name].splitlines(True) if not line.startswith(b'BW_PHASE '))
                archive = pack(files)
                (folder/'proof.tar.gz').write_bytes(archive)
                proof['archive'].update(sha256=digest(archive), bytes=len(archive))
                proof['members'] = {name:{'sha256':digest(raw), 'bytes':len(raw)} for name,raw in files.items()}
                (folder/'verification.json').write_text(json.dumps(proof))
                result = self.execute('--manifest', str(folder/'verification.json'), '--archive', str(folder/'proof.tar.gz'))
                self.assertNotEqual(result.returncode, 0, mutation+' unexpectedly accepted')

    def test_current_source_check_rejects_unrelated_source_root(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self.execute('--current-source', '--source-root', temporary)
            self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == '__main__':
    unittest.main()
