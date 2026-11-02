"""Worked examples at the independent fixed-input oracle's public seam."""
import json
from pathlib import Path
import unittest

from window_reference import reference_family

HERE = Path(__file__).resolve().parent


def family(name):
    return next(f for f in json.loads((HERE / 'fixed.json').read_text())['families']
                if f['id'] == name)


class WindowReferenceTest(unittest.TestCase):
    def test_default_ns_first_full_window_uses_measurement_start(self):
        # T=1fs; rows 1..10 transfer 100 bytes at T+1fs through T+9ns+1fs.
        case = reference_family(family('continuous'))[1]
        w = case.windows[0]
        self.assertEqual((case.origin, w.u, w.ticks, w.left, w.full,
                          w.complete, w.eligible, w.bytes, w.events, w.y),
                         (1, 10, 10000001, 1, True, True, True, 1000, 10, 100.0))

    def test_dense_cycle_warmup_and_first_full_window_use_real_edges(self):
        # First edge=2fs, next edge=1ns+2fs. A cycle window excludes its
        # right edge, includes its left edge, and has nine warmup results.
        windows = reference_family(family('activity'))[6].windows
        self.assertEqual([(w.u, w.ticks, w.left, w.full, w.eligible,
                           w.bytes, w.events, w.y) for w in (windows[0], windows[8], windows[9], windows[10])],
                         [(1, 1000002, 2, False, False, 100, 1, 100.0),
                          (9, 9000002, 2, False, False, 900, 9, 100.0),
                          (10, 10000002, 2, True, True, 1000, 10, 100.0),
                          (11, 11000002, 1000002, True, True, 1000, 10, 100.0)])

    def test_reset_restarts_ns_epoch_and_quality_expires_at_half_open_left(self):
        windows = {w.ticks: w for w in reference_family(family('recovery'))[11].windows}
        # Unknown row81 is sampled at 80ns+2fs. Right=90ns+1fs still
        # covers it; right=91ns+1fs has left=81ns+1fs and excludes it.
        self.assertEqual([(windows[t].bytes, windows[t].complete) for t in
                          (80000001, 81000001, 90000001, 91000001)],
                         [(4000, True), (3600, False), (3600, False), (4000, True)])
        # Reset row172 asserts at171ns+2fs, releases at172ns+2fs.
        self.assertNotIn(172000001, windows)
        self.assertEqual([(windows[t].u, windows[t].left, windows[t].full,
                           windows[t].bytes) for t in (173000002, 182000002)],
                         [(173, 172000002, False, 400),
                          (182, 172000002, True, 4000)])

    def test_episode_bounds_use_tail_edge_silence_and_reset(self):
        # Short cycle burst: three events, tail at the fourth edge, ten
        # silent cycles to closure. Both origins include the 1ns case reset.
        case = reference_family(family('activity'))[7]
        self.assertEqual(case.origin, 176000001)
        e = case.episodes[0]
        self.assertEqual((e.first_ticks, e.end_ticks, e.end_u, e.close_ticks),
                         (176000002, 179000002, 3, 189000002))
        episodes = reference_family(family('recovery'))[11].episodes
        self.assertEqual([(e.first_ticks, e.end_ticks, e.end_u, e.close_ticks)
                          for e in episodes],
                         [(2, 171000002, 171, 171000002),
                          (172000002, 262000002, 262, 272000002)])

    def test_eligibility_distinguishes_zero_bytes_no_activity_and_q_closure(self):
        activity = reference_family(family('activity'))
        self.assertEqual(activity[8].windows[9].bytes, 0)
        self.assertTrue(activity[8].windows[9].eligible)  # valid zero-byte events
        self.assertFalse(any(w.eligible for w in activity[9].windows))
        self.assertEqual([(w.u, w.eligible) for w in activity[7].windows
                          if w.u in (9, 10, 12, 13, 14)],
                         [(9, False), (10, True), (12, True),
                          (13, False), (14, False)])
        recovery = reference_family(family('recovery'))[11].windows
        self.assertEqual([(w.ticks, w.eligible) for w in recovery
                          if w.ticks in (81000001, 90000001, 91000001,
                                         181000002, 182000002, 272000002)],
                         [(81000001, False), (90000001, False),
                          (91000001, True), (181000002, False),
                          (182000002, True), (272000002, False)])

    def test_ns_case_end_is_recorded_only_for_final_case(self):
        cases = reference_family(family('recovery'))
        self.assertEqual((cases[12].origin, cases[13].origin),
                         (275000001, 514000001))
        # The between-case reset disables recording at case12's 238ns end;
        # the final 2fs wait retains case13's result at its 264ns end.
        self.assertEqual((cases[12].windows[-1].ticks,
                          cases[13].windows[-1].ticks),
                         (512000001, 778000001))


if __name__ == '__main__':
    unittest.main()
