#!/usr/bin/env python3
"""Literal independent input contracts for the history matrix."""
from fractions import Fraction as F
import unittest
from history import HistoryScenario

class HistoryContracts(unittest.TestCase):
    def test_ns_full_scene_becomes_full_only_at_exact_end(self):
        s=HistoryScenario('history-common-ns-long-dense')
        self.assertEqual(s.window_count('point',0),40000)
        self.assertEqual(s.window('point',0,39999)['full'],0)
        w=s.window('group',255,40000)
        self.assertEqual((w['left'],w['right'],w['bytes'],w['events'],w['full'],w['gbps']),(0,40000000000,163840000,2560000,1,F(4096)))
    def test_cycle_full_scene_never_fabricates_the_missing_cycle(self):
        s=HistoryScenario('history-common-cycle-long-dense')
        self.assertEqual(s.width,80000)
        self.assertEqual(s.window_count('point',0),79999)
        w=s.window('point',0,79999)
        self.assertEqual((w['left'],w['right'],w['left_cycle'],w['right_cycle'],w['coverage_cycles']),(250000,39999750000,1,80000,79999))
        self.assertEqual((w['bytes'],w['events'],w['full'],w['warmup'],w['window_valid'],w['gbps']),(5119936,79999,0,1,0,F(128)))
        self.assertEqual(s.raw('point',0,80000)['total_bytes'],5120000)
    def test_short_dense_keeps_nominal_duration_and_every_edge(self):
        for basis,stride,pubs in [('ns',1,40000),('cycle',2,39999)]:
            s=HistoryScenario('history-max-'+basis+'-short-dense')
            self.assertEqual((s.points,len(s.groups),s.end,s.clock.edges,s.stride,s.window_count('point',0)),(16384,4096,40000000000,80000,stride,pubs))

if __name__=='__main__':unittest.main()
