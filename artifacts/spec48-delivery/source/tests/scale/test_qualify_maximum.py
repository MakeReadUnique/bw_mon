#!/usr/bin/env python3
"""Recorded-data qualification tests; never compile or launch a simulator."""
import gzip
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
RECORDED = HERE / 'evidence/maximum-final-preparation'


class MaximumQualification(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bw-max-qualification-test-')
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.source, self.attempt = root / 'source', root / 'attempt'
        snapshot = json.loads((RECORDED / 'source/source-index.json').read_text())
        for name, entry in snapshot['files'].items():
            target = self.source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(gzip.decompress((RECORDED / 'source' / entry['gzip_file']).read_bytes()))
        self.attempt.mkdir()
        bundle = json.loads((RECORDED / 'max-tracer-ns/bundle.json').read_text())
        for name, entry in bundle['files'].items():
            raw = gzip.decompress((RECORDED / 'max-tracer-ns' / entry['gzip_file']).read_bytes())
            (self.attempt / name).write_bytes(raw)

    def replay(self, *options):
        return subprocess.run([sys.executable, '-B', str(HERE / 'qualify_maximum.py'),
                               'replay', '--source', str(self.source),
                               '--attempt', str(self.attempt)] + list(options),
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              universal_newlines=True)

    def test_completed_tracer_cannot_qualify_as_nominal(self):
        result = self.replay()
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('tracer is preparation only', result.stdout)

    def test_genuine_small_record_replays_without_changing_original_evidence(self):
        before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in self.attempt.iterdir()}
        result = self.replay('--allow-tracer')
        self.assertEqual(result.returncode, 0, result.stdout)
        proof = json.loads(result.stdout.splitlines()[-1])
        self.assertEqual(proof['state'], 'RECORDED_PROFILE_REPLAY_PASSED')
        self.assertFalse(proof['nominal_acceptance_passed'])
        self.assertEqual((proof['verification']['observed_scopes'],
                          proof['verification']['checked_raw'],
                          proof['verification']['checked_windows']), (56, 26880, 1344))
        self.assertEqual(before, {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in self.attempt.iterdir()})

    def test_nominal_campaign_rejects_a_mislabeled_genuine_tracer_receipt(self):
        root = Path(self.temporary.name)
        campaign = root / 'campaign'
        campaign.mkdir()
        (campaign / 'max-ns-launch.json').write_bytes((RECORDED / 'max-tracer-ns/launch.json').read_bytes())
        output = root / 'accepted'
        result = subprocess.run([sys.executable, '-B', str(HERE / 'qualify_maximum.py'), 'archive',
                                 '--campaign', str(campaign), '--output', str(output),
                                 '--launcher', str(RECORDED / 'launch-recipe.py'),
                                 '--current-source', str(HERE.parents[1])],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('launch profile mismatch', result.stdout)
        self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
