"""Worked fixed-policy vectors for the raw-derived acceptance oracle."""
from fractions import Fraction
import unittest

from analysis import phase_reference
from model import configuration, TICKS, stimulus, frame_table, window_table, at_measurement_start, require_scene_inventory, PRIMARY, SUPPLEMENTAL


class FixedPhaseReference(unittest.TestCase):
    def test_current_matrix_keeps_original_delayed_input_and_its_fixed_equivalent(self):
        configs = [configuration(scene, basis) for scene in PRIMARY for basis in ('ns', 'cycle')]
        configs += [configuration(scene, 'ns') for scene in SUPPLEMENTAL]
        self.assertEqual(require_scene_inventory(configs), 43)
        with self.assertRaises(AssertionError):
            require_scene_inventory([c for c in configs if c['scene']!='e3_delayed_fixed'])

    def test_measurement_origin_moves_edges_resets_and_windows_without_changing_bytes(self):
        config = configuration('point_reset', 'ns')
        rows = stimulus(config)
        shifted, shifted_rows = at_measurement_start(config, rows, 123)
        original = window_table(config, rows, frame_table(rows))
        actual = window_table(shifted, shifted_rows, frame_table(shifted_rows))
        self.assertEqual(shifted_rows[0][0], rows[0][0]+123)
        self.assertEqual(shifted['end_ticks'], config['end_ticks']+123)
        for scope in original:
            for before, after in zip(original[scope], actual[scope]):
                self.assertEqual((after['start'], after['end'], after['bytes'], after['member']),
                                 (before['start']+123, before['end']+123, before['bytes'], before['member']))

    def phases(self, values, ticks=None):
        config = configuration('steady', 'ns')
        ticks = ticks or list(range(10, 10+len(values)))
        windows = [dict(epoch=0, full=True, bc=True, denom=True, start=(t-10)*TICKS,
                        end=t*TICKS, end_cycle=i+1, bw=Fraction(y))
                   for i, (t, y) in enumerate(zip(ticks, values))]
        episode = dict(epoch=0, first=1, last=100*TICKS, tail=101*TICKS,
                       confirm=113*TICKS, status=2)
        return phase_reference(config, 'p0', windows, episode)

    def test_seventh_constant_update_confirms_with_sixth_boundary(self):
        self.assertEqual(self.phases([100]*7), [dict(kind=2, start=15*TICKS,
                          end=101*TICKS, confirm=16*TICKS, known=True)])

    def test_adjacent_pairs_accept_eight_percent_noise_at_small_and_large_scales(self):
        for scale in (Fraction(1, 1000000), 1, 1000000):
            phases = self.phases([v*scale for v in [92, 108, 92, 108, 92, 108, 92]])
            self.assertEqual([(p['kind'], p['start'], p['confirm']) for p in phases],
                             [(2, 15*TICKS, 16*TICKS)])

    def test_raw_residuals_reject_oscillation_hidden_by_pair_averages(self):
        self.assertEqual(self.phases([70, 130, 70, 130, 70, 130, 70]), [])

    def test_actual_time_fit_accepts_linear_trend_across_clock_change(self):
        times = [10, 11, 12, 14, 18, 22, 26]
        phases = self.phases([10*t for t in times], times)
        self.assertEqual([(p['kind'], p['start'], p['confirm']) for p in phases],
                         [(1, 22*TICKS, 26*TICKS)])


if __name__ == '__main__':
    unittest.main()
