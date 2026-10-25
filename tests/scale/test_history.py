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

    def test_group_reset_clears_only_local_stats_and_keeps_source_epoch(self):
        s=HistoryScenario('history-common-ns-control-clock')
        self.assertEqual(s.clock.edges,79850)
        r=s.raw('group',0,601)
        self.assertEqual((r['epoch'],r['source_epoch'],r['byte_inc'],r['event_inc'],r['total_bytes'],r['reset_points']),(1,0,320,5,0,0))
        self.assertEqual(s.raw('group',0,79850)['total_bytes'],25359360)
        self.assertEqual(s.raw('group',224,79850)['total_bytes'],163532736)
        old,new=s.expected_episodes('group',0)
        self.assertEqual((old['status'],old['bytes_complete'],new['status'],new['bytes_complete']),(3,0,4,1))
        self.assertEqual(s.expected_episodes('group',224)[0]['bytes_complete'],0)
    def test_stop_keeps_physical_denominator_and_ns_expires_to_known_zero(self):
        ns=HistoryScenario('history-common-ns-control-clock')
        self.assertEqual((ns.window('point',0,200)['bytes'],ns.window('point',0,200)['window_valid']),(0,1))
        self.assertEqual(ns.window('point',0,201)['gbps'],F(384,7))
        cyc=HistoryScenario('history-common-cycle-control-clock')
        w=cyc.window('point',0,350)
        self.assertEqual((w['left'],w['right'],w['coverage_cycles'],w['bytes'],w['gbps'],w['bpc']),(543250000,600250000,7,448,F(448,57),F(64)))

if __name__=='__main__':unittest.main()
