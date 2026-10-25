#!/usr/bin/env python3
"""Literal contracts for the maximum-scale input, independent of DUT state."""
from fractions import Fraction as F
import unittest

from maximum import build_scenario, PROFILES


class MaximumContracts(unittest.TestCase):
    def test_each_acceptance_profile_keeps_every_native_limit(self):
        for name in PROFILES:
            if 'tracer' in name:
                continue
            s = build_scenario(name)
            self.assertEqual((s.points, len(s.groups), s.topology['direct_edges'],
                              s.topology['depth'], s.topology['max_direct_parents']),
                             (16384, 4096, 65536, 8, 16))
            self.assertEqual(s.topology['ungrouped_points'], [16383])
            self.assertEqual(s.clock.edges, 80000)
            self.assertEqual(s.end, 40000000000)
            self.assertTrue(s.manifest()['acceptance_profile'])

    def test_deep_group_exact_raw_sum_and_medium_window(self):
        s = build_scenario('max-ns')
        self.assertEqual(len(s.leaves[7]), 121)
        r = s.raw('group', 7, 80000)
        self.assertEqual((r['byte_inc'], r['event_inc'], r['total_bytes'], r['total_events']),
                         (7744, 121, 619520000, 9680000))
        w = s.window('group', 7, 4000)
        self.assertEqual((w['left'], w['right'], w['bytes'], w['events'], w['gbps']),
                         (39900000000, 40000000000, 1548800, 24200, F(15488)))
        self.assertEqual(s.identity('point', 16383), 'tb_bw_scale.points[16383].slot.mon')
        self.assertEqual(s.identity('group', 4095), 'scale.g4095')

    def test_short_unknown_is_known_part_and_recovers(self):
        s = build_scenario('max-ns-short-unknown')
        w = s.window('group', 7, 11)
        self.assertEqual((w['left'], w['right'], w['bytes'], w['events'],
                          w['bytes_complete'], w['events_complete']),
                         (100000000, 110000000, 154816, 2420, 0, 1))
        self.assertEqual(s.window('group', 7, 12)['bytes_complete'], 1)
        self.assertEqual(sum(0 in s.leaves[g] for g in s.groups), 23)

    def test_cycle_reset_preserves_ancestors_and_local_origin(self):
        s = build_scenario('max-cycle-short-reset')
        self.assertEqual((s.width, s.stride), (20, 20))
        before = s.window('group', 7, 10)
        during = s.window('group', 7, 11)
        self.assertEqual((before['right'], before['bytes'], before['reset']),
                         (100250000, 154880, 1))
        self.assertEqual((during['left'], during['right'], during['bytes'],
                          during['events'], during['reset']),
                         (100250000, 110250000, 154752, 2418, 1))
        self.assertEqual(s.window('group', 7, 12)['reset'], 0)
        self.assertEqual((s.window_count('point', 0), s.window_count('group', 7)), (3998, 3999))
        self.assertEqual(s.raw('point', 0, 80000)['total_bytes'], 5107072)
        self.assertEqual(s.raw('group', 7, 80000)['total_bytes'], 619519872)

    def test_small_public_tracer_has_depth_and_subgroup_fanout(self):
        s = build_scenario('max-tracer-ns')
        self.assertEqual((s.points, len(s.groups), s.topology['direct_edges'],
                          s.topology['depth'], s.topology['max_direct_parents']),
                         (32, 24, 53, 8, 16))
        self.assertEqual(s.topology['ungrouped_points'], [31])
        self.assertEqual(len(s.leaves[7]), 10)
        self.assertFalse(s.manifest()['acceptance_profile'])


if __name__ == '__main__':
    unittest.main()
