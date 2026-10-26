"""Contract tests for the executable acceptance budget and immutable cache key."""
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

from bounded import execute_stage, build_identity


class BoundedAcceptance(unittest.TestCase):
    def test_timeout_terminates_the_entire_child_process_group(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            command = [sys.executable, '-c',
                       'import subprocess,time,pathlib; p=subprocess.Popen(["sleep","60"]); '
                       'pathlib.Path("child.pid").write_text(str(p.pid)); time.sleep(60)']
            result = execute_stage(command, out, 'timed', 0.25)
            self.assertEqual('TIMED_OUT', result['state'])
            self.assertLess(result['elapsed_seconds'], 3)
            pid = int((out / 'child.pid').read_text())
            status = Path('/proc') / str(pid) / 'status'
            self.assertTrue(not status.exists() or 'State:\tZ' in status.read_text())
            self.assertTrue((out / 'timed.log').exists())

    def test_nonzero_exit_is_never_a_completed_stage(self):
        with tempfile.TemporaryDirectory() as d:
            result = execute_stage([sys.executable, '-c', 'raise SystemExit(7)'], Path(d), 'failed', 3)
            self.assertEqual('FAILED', result['state'])
            self.assertEqual(7, result['returncode'])

    def test_successful_parent_must_not_leave_a_running_child(self):
        with tempfile.TemporaryDirectory() as d:
            result = execute_stage([sys.executable, '-c',
                'import subprocess; subprocess.Popen(["sleep","60"])'], Path(d), 'escaped', 3)
            self.assertEqual('FAILED_DESCENDANTS', result['state'])
            self.assertTrue(result['descendants_terminated'])

    def test_ready_marker_is_recorded_when_simulation_exits_between_polls(self):
        with tempfile.TemporaryDirectory() as d:
            result = execute_stage([sys.executable, '-c',
                'print("ACCEPTANCE_READY", flush=True)'], Path(d), 'simulation', 3)
            self.assertEqual('COMPLETED', result['state'])
            self.assertIn('initialization_seconds', result)
            self.assertIsNotNone(result['simulation_after_ready_seconds'])

    def test_stage_allows_bounded_native_child_shutdown(self):
        with tempfile.TemporaryDirectory() as d:
            result = execute_stage([sys.executable, '-c',
                'import subprocess; subprocess.Popen(["sleep","0.15"])'], Path(d), 'shutdown', 3)
            self.assertEqual('COMPLETED', result['state'])
            self.assertLess(result['elapsed_seconds'], 2)

    def test_cache_identity_changes_with_each_consumed_input(self):
        original = {'source': {'a.sv': 'abc'}, 'inputs': {'input.txt': 'def'},
                    'tools': {'vcs': 'version'}, 'options': ['-full64']}
        expected = build_identity(original)
        for category in original:
            changed = json.loads(json.dumps(original))
            changed[category] = 'changed'
            self.assertNotEqual(expected, build_identity(changed), category)
        self.assertEqual(expected, build_identity(json.loads(json.dumps(original))))


if __name__ == '__main__':
    unittest.main()
