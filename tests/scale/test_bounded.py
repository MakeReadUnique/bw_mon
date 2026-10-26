"""Contract tests for the executable acceptance budget and immutable cache key."""
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import bounded

from bounded import execute_stage, build_identity, build_artifacts


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

    def test_shared_native_payload_is_part_of_cached_build_identity(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'simv').write_bytes(b'fixed launcher')
            (root/'simv.daidir').mkdir();library=root/'simv.daidir/runtime.so'
            library.write_bytes(b'original compiled model');before=build_artifacts(root)
            library.write_bytes(b'changed compiled model');after=build_artifacts(root)
            self.assertEqual(before['simv'],after['simv'])
            self.assertNotEqual(before,after)

    def test_forced_rebuild_keeps_each_original_native_receipt(self):
        # External compiler/process boundary only: this tests provenance, not SV.
        class ReceiptScenario:
            name='receipt-unit-probe';source_module='history_revised';budget_seconds=300;variant='baseline'
            def manifest(self):return {'scenario':self.name}
        attempts=[0]
        def external_stage(command,directory,name,timeout):
            directory.mkdir(parents=True,exist_ok=True)
            result=dict(state='COMPLETED',returncode=0,elapsed_seconds=0.001,cwd=str(directory),command=command)
            if name=='generation':
                for filename in ('input_pkg.sv','checker.sv','tb_bw_scale.sv','input.json','expect.cfg'):
                    (directory/filename).write_text('fixed receipt fixture\n')
            elif name=='compile':
                attempts[0]+=1;result['compile_attempt']=attempts[0]
                (directory/'simv').write_text('native payload '+str(attempts[0]))
            elif name=='verification':
                (directory/'verification.json').write_text('{"difference_count":0}\n')
            (directory/(name+'.log')).write_text('attempt '+str(attempts[0]))
            (directory/(name+'.time-v.txt')).write_text('receipt\n')
            bounded.save(directory/(name+'.stage.json'),result)
            return result
        with tempfile.TemporaryDirectory() as d, patch.object(bounded,'execute_stage',external_stage), \
             patch.object(bounded,'tool_identity',lambda:({'receipt_test':True},Path('/synthetic/include'))), \
             patch.object(bounded,'capture',lambda command:'receipt-test'):
            root=Path(d);scenario=ReceiptScenario()
            self.assertTrue(bounded.run_bounded(scenario,root,True))
            first=json.loads(Path(json.loads((root/(scenario.name+'-latest.json')).read_text())['manifest']).read_text())
            native=Path(first['build']);original=(native/'compile-success.json').read_bytes()
            # Existing second-resolution attempt names also need distinct IDs.
            time.sleep(1.01)
            self.assertTrue(bounded.run_bounded(scenario,root,True))
            second=json.loads(Path(json.loads((root/(scenario.name+'-latest.json')).read_text())['manifest']).read_text())
            self.assertNotEqual(first['build'],second['build'])
            self.assertEqual(original,(native/'compile-success.json').read_bytes())
            self.assertEqual('native payload 1',(native/'simv').read_text())


if __name__ == '__main__':
    unittest.main()
