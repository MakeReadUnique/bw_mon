#!/usr/bin/env python3
"""Exercise the publishing CLI in disposable SYNTHETIC review copies only.

The checked-in human ledger is never edited. These tests copy the frozen evidence
and run the actual publisher/fsdbreport, without simulation, capture or --pack.
"""
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SYNTHETIC_STATUS = 'SYNTHETIC_APPROVED_NOT_A_REAL_REVIEW'
SUMMARY_FILES = {'review.json', 'verification.json', 'INDEX.md', 'SHA256SUMS.json'}


class PublishReviewCLI(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bw-SYNTHETIC-review-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'SYNTHETIC_TEST_COPY_NOT_HUMAN_ATTESTATION.txt').write_text(
            'Disposable test copy. Every review record here is synthetic.\n')
        self.out = self.root / 'artifacts/acceptance'
        shutil.copytree(str(ROOT / 'artifacts/acceptance'), str(self.out))
        # Copy the source inputs declared by the public evidence manifests; the
        # stimulus itself is already retained in each original trace archive.
        dependencies = {'tests/acceptance/publish.py', 'tests/acceptance/evidence.py'}
        for manifest in self.out.glob('*/commands.json'):
            dependencies.update(json.loads(manifest.read_text())['dependency_sha256'])
        for name in dependencies:
            source, target = ROOT / name, self.root / name
            if source.is_file():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(str(source), str(target))
        self.synthetic = {
            'status': SYNTHETIC_STATUS,
            'reviewer': 'SYNTHETIC_FIXTURE_NOT_A_PERSON',
            'date': '2099-01-01T00:00:00Z (SYNTHETIC TEST DATE)',
            'objects_intervals_conclusion': (
                'SYNTHETIC TEST ONLY: named steady_ns [92,102)ns; '
                'no real human review or approval is represented.'),
            'synthetic_test_only': True,
        }
        self.synthetic_agent = {
            'status': 'SYNTHETIC_AGENT_IMAGE_CHECK_NOT_HUMAN',
            'reviewer_type': 'SYNTHETIC AGENT FIXTURE ONLY',
            'entries': [{'image': 'steady_ns/overview.png',
                         'sha256': hashlib.sha256(
                             (self.out / 'steady_ns/overview.png').read_bytes()).hexdigest()}],
        }

    def read(self, name):
        return json.loads((self.out / name).read_text())

    def snapshot_evidence(self):
        return {
            str(path.relative_to(self.out)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in self.out.rglob('*')
            if path.is_file() and str(path.relative_to(self.out)) not in SUMMARY_FILES
        }

    def seed_synthetic_review(self):
        ledger = self.read('review.json')
        ledger['human'] = self.synthetic
        ledger['agent'] = self.synthetic_agent
        (self.out / 'review.json').write_text(json.dumps(ledger, indent=2) + '\n')
        return ledger['asset_fingerprint']

    def publish(self):
        result = subprocess.run(
            [sys.executable, str(self.root / 'tests/acceptance/publish.py')],
            cwd=str(self.root), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            universal_newlines=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('PASS durable assets: 42 scenes', result.stdout)

    def test_republish_preserves_named_review_and_renders_current_global_status(self):
        fingerprint = self.seed_synthetic_review()
        evidence = self.snapshot_evidence()
        self.publish()
        ledger, verification = self.read('review.json'), self.read('verification.json')
        self.assertEqual(ledger['asset_fingerprint'], fingerprint)
        self.assertEqual(ledger['human'], self.synthetic)
        self.assertEqual(ledger['agent'], self.synthetic_agent)
        self.assertEqual(verification['human_review'], SYNTHETIC_STATUS)
        index = (self.out / 'INDEX.md').read_text()
        self.assertIn(SYNTHETIC_STATUS, index)
        self.assertNotIn('humanT6reviewPENDING', index)
        self.assertIn('Automated performance summary', index)
        self.assertIn('named objects and intervals', index)
        for scene in verification['scenes']:
            # Historical capture state must not imply individual human approval.
            self.assertEqual(scene['human_review_at_generation'], 'PENDING')
            self.assertNotIn('human_review', scene)
        self.assertEqual(self.snapshot_evidence(), evidence,
                         'Republishing must preserve every original evidence byte')

    def test_changed_asset_clears_current_review_without_rewriting_evidence(self):
        fingerprint = self.seed_synthetic_review()
        # Deliberately change one disposable view, never the real frozen asset.
        view = self.out / 'steady_ns/overview.sav'
        view.write_bytes(view.read_bytes() + b'\n# SYNTHETIC TEST ASSET CHANGE\n')
        evidence = self.snapshot_evidence()
        self.publish()
        ledger, verification = self.read('review.json'), self.read('verification.json')
        self.assertNotEqual(ledger['asset_fingerprint'], fingerprint)
        self.assertEqual(ledger['human']['status'], 'PENDING')
        for field in ['reviewer', 'date', 'objects_intervals_conclusion']:
            self.assertIsNone(ledger['human'][field])
        self.assertEqual(ledger['previous_human_record'], self.synthetic)
        self.assertEqual(ledger['agent']['status'], 'PENDING')
        self.assertEqual(ledger['previous_agent_record'], self.synthetic_agent)
        self.assertEqual(verification['human_review'], 'PENDING')
        index = (self.out / 'INDEX.md').read_text()
        self.assertIn('human T6 ledger status: PENDING', index)
        self.assertNotIn(SYNTHETIC_STATUS, index)
        self.assertEqual(self.snapshot_evidence(), evidence,
                         'Resetting review must not rewrite original evidence')

    def test_review_of_external_view_is_invalidated_when_that_view_changes(self):
        view_name = 'artifacts/review-analog/start_stop_ns.sav'
        view = self.root / view_name
        view.parent.mkdir(parents=True)
        shutil.copyfile(str(ROOT / view_name), str(view))
        self.synthetic['artifact_sha256'] = {
            view_name: hashlib.sha256(view.read_bytes()).hexdigest(),
        }
        fingerprint = self.seed_synthetic_review()
        evidence = self.snapshot_evidence()
        self.publish()
        self.assertEqual(self.read('review.json')['human'], self.synthetic)
        view.write_bytes(view.read_bytes() + b'\n# SYNTHETIC CHANGED REVIEW VIEW\n')
        self.publish()
        ledger = self.read('review.json')
        self.assertEqual(ledger['asset_fingerprint'], fingerprint)
        self.assertEqual(ledger['human']['status'], 'PENDING')
        self.assertEqual(ledger['previous_human_record'], self.synthetic)
        self.assertEqual(self.read('verification.json')['human_review'], 'PENDING')
        self.assertEqual(self.snapshot_evidence(), evidence)

    def test_analog_verifier_accepts_review_refresh_but_rejects_changed_evidence(self):
        analog = self.root / 'artifacts/review-analog'
        shutil.copytree(str(ROOT / 'artifacts/review-analog'), str(analog))
        name = 'artifacts/review-analog/start_stop_ns.sav'
        self.synthetic['artifact_sha256'] = {
            name: hashlib.sha256((self.root / name).read_bytes()).hexdigest(),
        }
        self.seed_synthetic_review()
        self.publish()

        def verify_analog():
            return subprocess.run(
                [sys.executable, str(analog / 'verify.py')], cwd=str(self.root),
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                universal_newlines=True, timeout=30)

        result = verify_analog()
        self.assertEqual(result.returncode, 0, result.stdout)
        # Updated current inventories must not bless a changed historical view.
        view = self.out / 'steady_ns/overview.sav'
        original = view.read_bytes()
        inventory_path = self.out / 'SHA256SUMS.json'
        inventory_bytes = inventory_path.read_bytes()
        view.write_bytes(original + b'\n# SYNTHETIC CHANGED HISTORICAL EVIDENCE\n')
        inventory = json.loads(inventory_bytes.decode())
        inventory['steady_ns/overview.sav'] = hashlib.sha256(view.read_bytes()).hexdigest()
        inventory_path.write_text(json.dumps(inventory, indent=2) + '\n')
        self.assertNotEqual(verify_analog().returncode, 0)
        view.write_bytes(original)
        inventory_path.write_bytes(inventory_bytes)
        # Nor may a current summary change without the publisher's checksum update.
        index = self.out / 'INDEX.md'
        index.write_bytes(index.read_bytes() + b'\nSYNTHETIC UNPUBLISHED STATUS EDIT\n')
        self.assertNotEqual(verify_analog().returncode, 0)

    def test_third_publication_retains_one_archived_review_while_current_is_pending(self):
        self.seed_synthetic_review()
        self.publish()  # First: preserve the same-fingerprint synthetic record.
        view = self.out / 'steady_ns/overview.sav'
        view.write_bytes(view.read_bytes() + b'\n# SYNTHETIC TEST ASSET CHANGE\n')
        evidence = self.snapshot_evidence()
        self.publish()  # Second: invalidate current review and archive it once.
        invalidated = self.read('review.json')
        self.assertEqual(invalidated['previous_human_record'], self.synthetic)
        self.publish()  # Third: same changed assets, current review still pending.
        ledger = self.read('review.json')
        self.assertTrue('previous_human_record' in ledger,
                        'Third publication lost the archived SYNTHETIC record')
        self.assertEqual(ledger['previous_human_record'], self.synthetic)
        self.assertEqual(ledger['agent']['status'], 'PENDING')
        self.assertEqual(ledger['previous_agent_record'], self.synthetic_agent)
        self.assertEqual((self.out / 'review.json').read_text().count(SYNTHETIC_STATUS), 1)
        self.assertEqual(ledger['asset_fingerprint'], invalidated['asset_fingerprint'])
        self.assertEqual(ledger['human']['status'], 'PENDING')
        for field in ['reviewer', 'date', 'objects_intervals_conclusion']:
            self.assertIsNone(ledger['human'][field])
        self.assertEqual(self.read('verification.json')['human_review'], 'PENDING')
        index = (self.out / 'INDEX.md').read_text()
        self.assertIn('human T6 ledger status: PENDING', index)
        self.assertNotIn(SYNTHETIC_STATUS, index)
        self.assertEqual(self.snapshot_evidence(), evidence,
                         'Repeated pending publication must preserve evidence bytes')

    def test_rejects_wrong_consumed_c_or_local_header_metadata(self):
        manifest = self.out / 'child_reset_cycle/commands.json'
        original = manifest.read_text()
        ledger = (self.out / 'review.json').read_bytes()
        for name in ['rtl/bw_slot_settlement.c', 'rtl/bw_reset_capture.svh']:
            with self.subTest(consumed_source=name):
                changed = json.loads(original)
                changed['dependency_sha256'][name] = '0' * 64
                manifest.write_text(json.dumps(changed, indent=2) + '\n')
                evidence = self.snapshot_evidence()
                result = subprocess.run(
                    [sys.executable, str(self.root / 'tests/acceptance/publish.py')],
                    cwd=str(self.root), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    universal_newlines=True, timeout=120)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('scene consumed a different runtime', result.stdout)
                self.assertEqual((self.out / 'review.json').read_bytes(), ledger)
                self.assertEqual(self.snapshot_evidence(), evidence)
        manifest.write_text(original)

    def test_rejects_wrong_sdk_header_hash_without_editing_the_sdk(self):
        freeze = self.out / 'runtime-source.json'
        changed = json.loads(freeze.read_text())
        sdk = changed['native_header_dependencies']['vendor_headers'][0]
        changed['native_header_dependencies']['header_sha256'][sdk] = '0' * 64
        freeze.write_text(json.dumps(changed, indent=2) + '\n')
        ledger = (self.out / 'review.json').read_bytes()
        evidence = self.snapshot_evidence()
        result = subprocess.run(
            [sys.executable, str(self.root / 'tests/acceptance/publish.py')],
            cwd=str(self.root), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            universal_newlines=True, timeout=120)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('native header changed', result.stdout)
        self.assertEqual((self.out / 'review.json').read_bytes(), ledger)
        self.assertEqual(self.snapshot_evidence(), evidence)


if __name__ == '__main__':
    unittest.main(verbosity=2)
