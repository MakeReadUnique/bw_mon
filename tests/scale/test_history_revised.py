"""Literal contracts for the expanded-event history acceptance oracle."""
import unittest
import tempfile
from pathlib import Path
from fractions import Fraction
from history_revised import EventOracle, build_scenario
from history_revised_audit import verify_storage
from history_revised_analysis import phase_reference


class ExpandedHistoryContracts(unittest.TestCase):
    def test_public_start_rebases_full_budget_without_losing_endpoint_publications(self):
        original = EventOracle([(250000, 1, 1, 64, 1, 1, 64)],
                               end=40000000000, basis='ns', width=1, stride=1)
        shifted = original.at_measurement_start(123)
        self.assertEqual(shifted.publication_count, 40000)
        self.assertEqual(shifted.raw(0, 1)['tick'], 250123)
        self.assertEqual((shifted.window(0, 40000)['left'], shifted.window(0, 40000)['right']),
                         (39999000123, 40000000123))
        self.assertEqual(shifted.window(0, 1)['gbps'], original.window(0, 1)['gbps'])

    def test_fixed_phase_uses_raw_six_window_pairs_and_seventh_confirmation(self):
        oracle = EventOracle([(250000+i*1000000, 1, 1, value, 1, 1, 64)
                              for i, value in enumerate((92, 108, 92, 108, 92, 108, 92))],
                             end=7000000, basis='ns', width=1, stride=1)
        episode = dict(first_ticks=250000, last_ticks=6250000, tail_ticks=7250000,
                       confirm_ticks=37250000, status=2, episode=1)
        phases = phase_reference(oracle, 0, [episode])
        self.assertEqual([(p['kind'], p['start_ticks'], p['confirm_ticks'], p['end_ticks']) for p in phases],
                         [(2, 6000000, 7000000, 7250000)])

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


class ResetAwareOracleContracts(unittest.TestCase):
    """Own resets restart statistics; member resets only mark quality."""

    def events(self, count, byte0=8, byte1=64):
        return [(250000+i*1000000, 1, 1, byte0, 1, 1, byte1) for i in range(count)]

    def test_ns_own_reset_restarts_publication_grid_epoch_and_totals(self):
        oracle = EventOracle(self.events(10), end=10000000, basis='ns', width=4, stride=2,
                             resets={0: [(3500000, 6500000)]})
        # Segment 0 publishes only grid points before the assert tick 3.5ns;
        # segment 1 restarts at release+2ns with a new epoch and warmup.
        self.assertEqual([ (w['seq'], w['epoch'], w['right']) for w in oracle.windows(0) ],
                         [(1, 0, 2000000), (2, 1, 8500000)])
        first, second = oracle.windows(0)
        self.assertEqual((first['left'], first['warmup'], first['bytes'], first['events'], first['reset']),
                         (0, 1, 16, 2, 0))
        self.assertEqual((second['left'], second['warmup'], second['bytes'], second['events'], second['reset']),
                         (6500000, 1, 16, 2, 0))
        # Own-reset records are zero, marked, and never re-enter totals.
        self.assertEqual([oracle.raw(0, e)['total_bytes'] for e in (1, 4, 5, 7, 8, 10)],
                         [8, 32, 0, 0, 8, 24])
        self.assertEqual([(oracle.raw(0, e)['epoch'], oracle.raw(0, e)['reset_points']) for e in (4, 5, 7, 8)],
                         [(0, 0), (1, 1), (1, 1), (1, 0)])

    def test_ns_member_reset_keeps_group_grid_and_marks_window_coverage(self):
        oracle = EventOracle(self.events(10), end=10000000, basis='ns', width=4, stride=2,
                             resets={0: [(3500000, 6500000)]})
        self.assertEqual([w['seq'] for w in oracle.windows(2)], [1, 2, 3, 4, 5])
        final = oracle.window(2, 5)
        self.assertEqual((final['left'], final['right'], final['full'], final['reset'],
                          final['bytes'], final['events']), (6000000, 10000000, 1, 1, 280, 7))

    def test_cycle_own_reset_restarts_edge_grid_from_new_origin(self):
        oracle = EventOracle(self.events(8), end=8000000, basis='cycle', width=3, stride=2,
                             resets={0: [(3500000, 6500000)]})
        windows = list(oracle.windows(0))
        self.assertEqual([(w['seq'], w['epoch'], w['right_cycle'], w['left_cycle']) for w in windows],
                         [(1, 0, 3, 1)])
        self.assertEqual((windows[0]['left'], windows[0]['right'], windows[0]['warmup'],
                          windows[0]['bytes'], windows[0]['reset']), (250000, 2250000, 1, 16, 0))
        # Uninterrupted scopes keep the original grid: edges 3, 5 and 7 publish.
        self.assertEqual([len(list(oracle.windows(scope))) for scope in range(3)], [1, 3, 3])

    def test_reset_scenarios_declare_original_pressure_and_endpoint_contract(self):
        for name in ('history-revised-ns-reset', 'history-revised-cycle-reset'):
            scenario = build_scenario(name)
            manifest = scenario.manifest()
            self.assertIn('H2', manifest['properties'])
            self.assertIn('H5', manifest['properties'])
            self.assertEqual(manifest['basis'], name.split('-')[2])
            self.assertTrue(manifest['resets'])
            self.assertEqual(manifest['end_ticks'], 40000000000)
            self.assertEqual(manifest['actual_edges'], 80000)
            self.assertEqual(manifest['first_edge_ticks'], 250000)

    def test_overrun_scenario_drives_past_the_immutable_budget(self):
        scenario = build_scenario('history-revised-ns-overrun')
        manifest = scenario.manifest()
        self.assertEqual(manifest['basis'], 'ns')
        self.assertEqual(manifest['overrun_edges'], 3)
        # Driving continues past the immutable budget; expectations stop at it.
        self.assertEqual(manifest['end_ticks'], 40000000000)
        self.assertEqual(manifest['driven_end_ticks'], 40001250000)
        self.assertEqual(manifest['windows_per_scope'], [40000]*3)


if __name__ == '__main__':
    unittest.main()
