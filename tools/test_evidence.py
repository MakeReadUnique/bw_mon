#!/usr/bin/env python3
"""Exercise restoration with real Git objects and existing local user data."""
import subprocess
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from evidence import extract_snapshot, check_current_source


class CurrentSourceEvidence(unittest.TestCase):
    def test_current_delivery_checks_new_source_without_relabelling_historical_hashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'evidence').mkdir();(root/'rtl').mkdir()
            source=root/'rtl/example.sv';source.write_text('new measured source\n')
            old={'files':{'rtl/example.sv':hashlib.sha256(b'old measured source\n').hexdigest()}}
            (root/'evidence/source-hashes.json').write_text(json.dumps(old))
            delivery={'source_sha256':{'rtl/example.sv':hashlib.sha256(source.read_bytes()).hexdigest()}}
            (root/'evidence/spec48-delivery.json').write_text(json.dumps(delivery))
            check_current_source(root)
            self.assertEqual(json.loads((root/'evidence/source-hashes.json').read_text()),old)
            source.write_text('later unqualified change\n')
            with self.assertRaisesRegex(ValueError,'example.sv'):
                check_current_source(root)

    def test_new_production_file_cannot_escape_current_delivery_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'evidence').mkdir();(root/'rtl').mkdir()
            (root/'evidence/spec48-delivery.json').write_text(json.dumps({'source_sha256':{}}))
            (root/'rtl/new.sv').write_text('new unqualified module\n')
            with self.assertRaisesRegex(ValueError,'new.sv'):
                check_current_source(root)


class RestoreEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='bw-evidence-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-q')
        folder = self.repo / 'records'
        folder.mkdir()
        (folder / 'a.txt').write_bytes(b'original first\n')
        (folder / 'z.txt').write_bytes(b'original last\n')
        self.git('add', '.')
        self.git('-c', 'user.name=Evidence Test', '-c', 'user.email=test@example.invalid',
                 '-c', 'commit.gpgsign=false', 'commit', '-qm', 'recorded fixture')
        self.revision = self.git('rev-parse', 'HEAD').strip()

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.repo)] + list(arguments),
                                       universal_newlines=True, stderr=subprocess.STDOUT)

    def test_restores_exact_snapshot_and_is_idempotent(self):
        (self.repo / 'records/a.txt').write_text('uncommitted later content')
        output = self.root / 'output'
        for _ in range(2):
            self.assertEqual(extract_snapshot(self.repo, self.revision, ['records'], output), 2)
            self.assertEqual((output / 'records/a.txt').read_bytes(), b'original first\n')
            self.assertEqual((output / 'records/z.txt').read_bytes(), b'original last\n')

    def test_refuses_changed_evidence_before_writing_any_file(self):
        output = self.root / 'output'
        (output / 'records').mkdir(parents=True)
        (output / 'records/z.txt').write_text('local results must survive')
        with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
            extract_snapshot(self.repo, self.revision, ['records'], output)
        self.assertFalse((output / 'records/a.txt').exists())
        self.assertEqual((output / 'records/z.txt').read_text(), 'local results must survive')

    def test_refuses_destination_symlink_and_keeps_outside_files(self):
        output, outside = self.root / 'output', self.root / 'outside'
        output.mkdir()
        outside.mkdir()
        (output / 'records').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'destination symlink'):
            extract_snapshot(self.repo, self.revision, ['records'], output)
        self.assertEqual(list(outside.iterdir()), [])

    def test_missing_commit_reports_explicit_fetch(self):
        with self.assertRaisesRegex(ValueError, 'git fetch origin'):
            extract_snapshot(self.repo, '0' * 40, ['records'], self.root / 'output')


if __name__ == '__main__':
    unittest.main()
