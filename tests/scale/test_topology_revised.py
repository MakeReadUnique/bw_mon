import unittest
from topology_revised import build_scenario


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
