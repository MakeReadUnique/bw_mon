import unittest
from topology_revised import build_scenario, interaction_diffs


class RevisedTopology(unittest.TestCase):
    def test_maximum_graph_and_independent_leaf_identity(self):
        s = build_scenario('topology-max-ns')
        self.assertEqual((16384, 4096, 65536, 8, 16), tuple(s.topology[k] for k in
                         ('points','groups','direct_edges','depth','max_direct_parents')))
        self.assertIn(16383, s.topology['ungrouped_points'])
        self.assertEqual(184, s.raw('group', 0, 1)['byte_inc'])
        self.assertEqual(320, s.raw('group', 0, 2)['total_bytes'])
        self.assertEqual(589, s.raw('group', 1, 1)['byte_inc'])
        self.assertNotEqual(s.raw('point', 14, 1)['byte_inc'], s.raw('point', 15, 1)['byte_inc'])
        self.assertEqual(16, sum(('group',0) in members for members in s.groups.values()))

    def test_same_time_hold_expectations_derived_from_frozen_schedule(self):
        for name in ('topology-quick-ns', 'topology-max-cycle'):
            s = build_scenario(name)
            # The interaction source is the shared 16-parent subgroup; the slow
            # consumer set and its 15 fast peers come from the topology itself.
            consumers = [g for g, members in s.groups.items() if ('group', s.interaction_source) in members]
            self.assertEqual(16, len(consumers))
            self.assertIn(s.slow_consumer, consumers)
            self.assertEqual(sorted(g for g in consumers if g != s.slow_consumer), s.fast_consumers)
            # Event one: the member reset release control (101.1ns) forwards in
            # its own stamp slot; the assert control (100.1ns) settled ungated.
            self.assertEqual(101100000, s.control_hold_tick)
            self.assertEqual(1, s.held_control_count)
            # Event two: the gate edge slot. The slow consumer has settled every
            # earlier slot, so exactly that slot's own single frame is unread
            # while the fifteen fast peers already acked it; its controls are
            # empty because the release control settled in its own earlier slot.
            self.assertEqual(203, s.gate_edge)
            self.assertEqual(1, s.held_frame_count)
            self.assertEqual((202, 203), (s.slow_consumer_ack, s.fast_consumer_ack))
            # Release completes inside the gate edge's own slot.
            self.assertEqual(s.clock.at(s.gate_edge), s.release_tick)
            # The slow consumer's ns timers cannot pass its unread evidence.
            self.assertEqual(101, s.slow_timer_bound_ns)

    def test_cancellation_profile_expects_one_disabled_terminal(self):
        s = build_scenario('topology-max-cancel-ns')
        self.assertTrue(s.cancel_interaction)
        self.assertEqual(20480, s.points + len(s.groups))
        self.assertEqual([s.slow_consumer], s.cancelled_scopes)
        self.assertEqual(20479, s.expected_csv_scopes)
        self.assertEqual(20480, s.expected_terminal_scopes)

    def test_interaction_markers_are_checked_from_the_log(self):
        s = build_scenario('topology-max-ns')
        control = ('TOPOLOGY_BACKLOG_CONTROL source=scale.g0 consumers=16 retained_controls=1 retained_frames=0\n'
                   'TOPOLOGY_CONTROL_RELEASE original_time=1 released_controls=1\n')
        frame = ('TOPOLOGY_BACKLOG source=scale.g0 consumers=16 fast_ack=203 slow_ack=202 '
                 'retained_frames=1 retained_controls=0 history_segments=4\n')
        release = 'TOPOLOGY_INTERACTION_PASS original_time=1 all_consumers_released=1 basis=0\n'
        self.assertEqual([], interaction_diffs(control + frame + release, s))
        self.assertTrue(interaction_diffs(frame + release, s))            # control markers missing
        self.assertTrue(interaction_diffs(control + release, s))          # frame backlog missing
        self.assertTrue(interaction_diffs(control + frame, s))            # release marker missing
        # Wrong retained counts must be detected, not just presence-checked.
        wrong = control.replace('retained_controls=1', 'retained_controls=2') + frame + release
        self.assertTrue(interaction_diffs(wrong, s))
        wrong = control + frame.replace('retained_frames=1', 'retained_frames=5') + release
        self.assertTrue(interaction_diffs(wrong, s))
        duplicated = control + frame + release + release
        self.assertTrue(interaction_diffs(duplicated, s))

    def test_cancellation_markers_require_release_and_healthy_chain(self):
        s = build_scenario('topology-max-cancel-ns')
        control = ('TOPOLOGY_BACKLOG_CONTROL source=scale.g0 consumers=16 retained_controls=1 retained_frames=0\n'
                   'TOPOLOGY_CONTROL_RELEASE original_time=1 released_controls=1\n')
        frame = ('TOPOLOGY_BACKLOG source=scale.g0 consumers=16 fast_ack=203 slow_ack=202 '
                 'retained_frames=1 retained_controls=0 history_segments=4\n')
        good = (control + frame +
                'TOPOLOGY_CANCEL_RELEASE root=scale.g8 frames=0 controls=0 slow_ack=202 healthy_source=scale.g0\n'
                'TOPOLOGY_CANCEL_HEALTHY source=scale.g0 accepted=204 basis=0\n'
                'TOPOLOGY_CANCEL_PASS cancelled_consumers=1 released=1 basis=0\n')
        self.assertEqual([], interaction_diffs(good, s))
        self.assertTrue(interaction_diffs(good.replace('TOPOLOGY_CANCEL_HEALTHY source=scale.g0 accepted=204 basis=0\n', ''), s))
        # The positive-run marker belongs to a different profile shape.
        self.assertTrue(interaction_diffs(control + frame +
                                          'TOPOLOGY_INTERACTION_PASS original_time=1 all_consumers_released=1 basis=0\n', s))

    def test_member_reset_splits_exactly_the_covering_non_owner_platforms(self):
        s = build_scenario('topology-quick-ns')
        # p0's own reset lands on its episode boundary; the group owner keeps
        # two episodes; every other covering scope gains one interrupted row.
        self.assertEqual(2, s.expected_default_rows('point', 0))
        self.assertEqual(3, s.expected_default_rows('group', 0))
        self.assertEqual(2, s.expected_default_rows('group', 1))
        self.assertEqual(2, s.expected_default_rows('group', 22))
        self.assertEqual(1, s.expected_default_rows('group', 23))
        self.assertEqual(1, s.expected_default_rows('point', 1))
        interrupted = s.interrupted_platform_scopes()
        self.assertEqual(24, len(interrupted))          # p0 plus g0..g22
        self.assertIn('scale.g22', interrupted)
        self.assertIn(s.identity('point', 0), interrupted)
        self.assertNotIn('scale.g23', interrupted)
        # In the cycle basis the same tail cannot rebuild a W128-cycle
        # reference: the reset owner gains no row and no interrupted reason
        # appears; only the covering non-owner scopes keep the extra row.
        c = build_scenario('topology-quick-cycle')
        self.assertEqual(2, c.expected_default_rows('point', 0))
        self.assertEqual(2, c.expected_default_rows('group', 0))
        self.assertEqual(2, c.expected_default_rows('group', 1))
        self.assertEqual(1, c.expected_default_rows('group', 23))
        self.assertEqual(set(), c.interrupted_platform_scopes())

    def test_unknown_reset_and_complete_episode_are_separate(self):
        s = build_scenario('topology-max-ns')
        self.assertEqual((0, 1, 0), tuple(s.raw('point',0,193)[k] for k in ('byte_inc','event_inc','bytes_complete')))
        self.assertEqual(0, s.raw('point',0,201)['event_inc'])
        self.assertEqual((184, 0), tuple(s.raw('group',0,257)[k] for k in ('byte_inc','total_bytes')))
        self.assertGreater(s.raw('group',1,257)['total_bytes'], 0)
        self.assertEqual(5116, s.window('group',0,97)['bytes'])
        episode = s.expected_episodes('point',1)[0]
        self.assertEqual((1344,384,2,192250000), tuple(episode[k] for k in ('bytes','events','status','tail_ticks')))
        self.assertEqual(0, s.final_scope('group',1)['window_bytes'])


if __name__ == '__main__':
    unittest.main()
