#!/usr/bin/env python3
"""Exercise the recorded-proof CLI; process exit is never an acceptance result."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class HistoryProofGuards(unittest.TestCase):
    def test_finished_common_queue_requires_all_six_independent_audits(self):
        with tempfile.TemporaryDirectory(prefix='bw-history-proof-guard-') as temp:
            archive = Path(temp) / 'tests/scale/history_evidence/final-campaign'
            shutil.copytree(str(HERE), str(archive))
            checkpoint = json.loads((archive / 'controller-checkpoint.json').read_text())
            common = checkpoint['controllers']['common-history']
            self.assertFalse(common['alive_at_checkpoint'])
            entry = common['files']['common-scheduler-status.json']
            status_path = archive / entry['file']
            status = json.loads(status_path.read_text())
            status['audited_profiles'].remove('history-common-ns-control-clock')
            status_path.write_text(json.dumps(status, indent=2, sort_keys=True) + '\n')
            # Preserve hash consistency so only the false acceptance claim fails.
            raw = status_path.read_bytes()
            entry.update(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
            checkpoint_path = archive / 'controller-checkpoint.json'
            checkpoint_path.write_text(json.dumps(checkpoint, indent=2, sort_keys=True) + '\n')
            proof_path = archive / 'verification.json'
            proof = json.loads(proof_path.read_text())
            proof['controller_checkpoint_sha256'] = hashlib.sha256(checkpoint_path.read_bytes()).hexdigest()
            proof_path.write_text(json.dumps(proof, indent=2, sort_keys=True) + '\n')
            result = subprocess.run([sys.executable, '-B', str(archive / 'verify.py')],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    universal_newlines=True)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertNotIn('FileNotFoundError', result.stdout)
            self.assertNotIn('PASS PARTIAL checkpoint:', result.stdout)


if __name__ == '__main__':
    unittest.main()
