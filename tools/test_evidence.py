#!/usr/bin/env python3
"""Exercise restoration with real Git objects and existing local user data."""
import subprocess
import tempfile
import unittest
from pathlib import Path

from evidence import extract_snapshot


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
