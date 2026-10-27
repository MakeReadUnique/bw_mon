"""Literal contracts for the expanded-event history acceptance oracle."""
import unittest
import tempfile
from pathlib import Path
from fractions import Fraction
from history_revised import EventOracle, build_scenario
from history_revised_audit import verify_storage


class ExpandedHistoryContracts(unittest.TestCase):
    def test_half_open_known_subtotals_and_first_full_nonmultiple_stride(self):
        # At 2ns, the right-edge transfer is still excluded. At 4ns the 0.25ns
        # transfer has expired and the unknown byte count remains unknown.
        oracle = EventOracle([(250000, 1, 1, 4, 1, 1, 8),
                              (1250000, 1, 1, 0, 1, 1, 8),
                              (2000000, 1, 0, 17, 1, 1, 8),
                              (3750000, 0, 1, 99, 1, 1, 8)],
                             end=4000000, basis='ns', width=3, stride=2)
        first, second = list(oracle.windows(2))
        self.assertEqual((first['bytes'], first['events'], first['full'], first['gbps']),
                         (20, 4, 0, Fraction(10)))
        self.assertEqual((second['left'], second['right'], second['bytes'], second['events'],
                          second['full'], second['bytes_complete'], second['events_complete']),
                         (1000000, 4000000, 24, 5, 1, 0, 1))
        self.assertEqual(oracle.raw(2, 4)['total_bytes'], 36)

    def test_deep_profile_reaches_80000_distinct_original_events_and_keeps_real_cycle_origin(self):
        scenario = build_scenario('history-revised-cycle-deep')
        oracle = scenario.oracle
        self.assertEqual((len(oracle.events), oracle.end, oracle.ticks[0], oracle.ticks[-1]),
                         (80000, 40000000000, 250000, 39999750000))
        self.assertEqual(oracle.raw(0, 80000)['total_bytes'], 343597383560000)
        final = oracle.window(0, oracle.publication_count)
        self.assertEqual((final['seq'], final['left_cycle'], final['right_cycle'], final['coverage_cycles'],
                          final['full'], final['warmup'], final['bytes']),
                         (79999, 1, 80000, 79999, 0, 1, 343593088592705))
        self.assertTrue(all(a[3] != b[3] for a, b in zip(oracle.events, oracle.events[1:])))
        self.assertEqual(scenario.manifest()['resource_contract']['event_segments'][0], 80000)

    def test_public_run_exports_original_input_and_independent_streams(self):
        scenario = build_scenario('history-revised-ns-seeded')
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            scenario.generate(out)
            self.assertEqual(len((out/'event-input.txt').read_text().splitlines()), 1024)
            # The initial original transfer is 8+64B, including both events.
            first = (out/'raw-2.txt').read_text().splitlines()[0].split()
            self.assertEqual(first[:10], ['1', '0', '250000', '1', '72', '2', '1', '1', '0', '72'])
            self.assertEqual(len((out/'window-2.txt').read_text().splitlines()), scenario.oracle.publication_count)
            self.assertIn('bw_point_mon', (out/'tb_bw_scale.sv').read_text())
            self.assertIn('bw_group_mon', (out/'tb_bw_scale.sv').read_text())

    def test_compressed_actual_representation_is_expanded_against_original_events(self):
        oracle = EventOracle([(250000+i*500000, 1, 1, b, 1, 1, 64)
                              for i, b in enumerate((4, 4, 4, 8, 8))],
                             end=3000000, basis='ns', width=2, stride=1)
        observed = ('S 0 1 3000000 5 1000000 0\n'
                    'E 0 1 1250000 3 1 500000 1 4 1 1 1 0 1250000 3\n'
                    'E 0 1 1750000 4 2 500000 1 8 1 1 1 0 2250000 5\n'
                    'Z 0 1\n')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'actual-runs.txt'
            path.write_text(observed)
            differences, counts = verify_storage(oracle, path)
            self.assertEqual(differences, [])
            self.assertEqual(counts['expanded_events'], 3)
            path.write_text(observed.replace('1250000 3 1', '1250001 3 1'))
            self.assertTrue(verify_storage(oracle, path)[0])

    def test_pending_suffix_profile_retains_thirty_thousand_real_publications(self):
        scenario = build_scenario('history-revised-pending')
        self.assertEqual(scenario.manifest()['pending_samples_minimum'], 30000)
        with tempfile.TemporaryDirectory() as tmp:
            scenario.generate(Path(tmp))
            source = (Path(tmp)/'tb_bw_scale.sv').read_text()
            self.assertIn('bw_point_mon', source)
            self.assertIn('episode_pending_samples', source)
            self.assertIn('selected_samples=3', source)


if __name__ == '__main__':
    unittest.main()
