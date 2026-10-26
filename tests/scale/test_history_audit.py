"""Negative public audit contracts: missing proof cannot become acceptance."""
import tempfile
from pathlib import Path
import unittest
import json
import gzip
from history_revised import build_scenario
from history_revised_audit import verify_storage, expected_snapshots, verify
from history_revised_analysis import episode_reference, phase_reference


class HistoryAuditContracts(unittest.TestCase):
    def test_empty_storage_cannot_replace_required_input_checkpoints(self):
        scenario = build_scenario('history-revised-ns-seeded')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'storage.txt'
            path.write_text(''.join('S %d 1 0 0 0 0\nZ %d 1\n' % (s, s) for s in range(3)))
            differences, _ = verify_storage(scenario.oracle, path, expected_snapshots(scenario))
            self.assertTrue(differences)

    def test_rational_fit_derives_complete_seeded_phase_lifecycle(self):
        scenario = build_scenario('history-revised-cycle-seeded')
        episodes = episode_reference(scenario.oracle, 0, 60)
        self.assertEqual(len(episodes), 1)
        phases = phase_reference(scenario.oracle, 0, episodes)
        self.assertEqual([(p['kind'], p['start_ticks'], p['end_ticks'], p['confirm_ticks']) for p in phases],
                         [(2, 12250000, 21250000, 16750000),
                          (2, 33250000, 45250000, 37750000),
                          (1, 45250000, 54250000, 49750000),
                          (2, 54250000, 70750000, 58750000)])

    def test_recorded_audit_rejects_missing_duplicated_and_forged_evidence(self):
        fixture = json.loads(gzip.decompress(Path(__file__).with_name('history_audit_fixture.json.gz').read_bytes()))
        scenario = build_scenario(fixture['profile'])
        mutations = ('baseline', 'missing_group_storage', 'empty_storage', 'duplicate_checkpoint',
                     'duplicate_checks', 'missing_phases', 'missing_variation', 'summary_counter')
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                out = Path(tmp)
                for name, value in fixture['files'].items():
                    (out/name).write_text(value)
                storage = out/'storage-runs.txt'
                log = out/'simulation.log'
                if mutation == 'missing_group_storage':
                    storage.write_text(''.join(x for x in storage.read_text().splitlines(True) if x.split()[1] != '2'))
                elif mutation == 'empty_storage':
                    storage.write_text(''.join('S %d 1 0 0 0 0\nZ %d 1\n' % (s, s) for s in range(3)))
                elif mutation == 'duplicate_checkpoint':
                    text = storage.read_text(); end = text.index('\nZ '); end = text.index('\n', end+1)
                    storage.write_text(text[:end+1]+text)
                elif mutation == 'duplicate_checks':
                    lines = log.read_text().splitlines(True)
                    first = next(x for x in lines if x.startswith('BW_CHECK '))
                    log.write_text(''.join(first if x.startswith('BW_CHECK ') else x for x in lines))
                elif mutation in ('missing_phases', 'missing_variation'):
                    prefix = 'BW_PHASE ' if mutation == 'missing_phases' else 'BW_VARIATION '
                    log.write_text(''.join(x for x in log.read_text().splitlines(True) if not x.startswith(prefix)))
                elif mutation == 'summary_counter':
                    log.write_text(log.read_text().replace('BW_SUMMARY status=WARNING pass=2', 'BW_SUMMARY status=WARNING pass=99'))
                self.assertEqual(verify(scenario, out)[0], mutation == 'baseline')


if __name__ == '__main__':
    unittest.main()
