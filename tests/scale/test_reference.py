#!/usr/bin/env python3
"""Small literal cross-checks of the independent scale reference, not DUT tests."""
from fractions import Fraction as F
import unittest
from scenario import Scenario, common_topology, maximum_topology, topology_summary

class ReferenceContracts(unittest.TestCase):
    def test_common_topology_is_balanced_and_not_reused(self):
        points,groups=common_topology(32)
        s,leaves=topology_summary(points,groups)
        self.assertEqual((points,len(groups),s['direct_edges'],s['depth'],s['max_direct_parents']),(1024,256,1248,2,1))
        self.assertEqual([len(leaves[g]) for g in range(224,256)],[32]*32)
        self.assertEqual(s['ungrouped_points'],[])

    def test_maximum_caps_are_simultaneous_and_ungrouped_point_survives(self):
        points,groups=maximum_topology()
        s,leaves=topology_summary(points,groups)
        self.assertEqual((points,len(groups),s['direct_edges'],s['depth'],s['max_direct_parents']),(16384,4096,65536,8,16))
        self.assertEqual(len(leaves[7]),121)
        self.assertEqual(s['ungrouped_points'],[16383])

    def test_mandatory_ns_endpoint_and_zero_warmup_ambiguity(self):
        s=Scenario('common-ns')
        w=s.window('group',255,4000)
        self.assertEqual((w['left'],w['right'],w['bytes'],w['events'],w['gbps']),(39900000000,40000000000,409600,6400,F(4096)))
        self.assertEqual(s.window_count('point',0),4000)
        self.assertEqual(s.raw('point',0,80000)['total_bytes'],5120000)

    def test_cycles_exclude_current_event_but_live_includes_it(self):
        s=Scenario('common-cycle')
        w=s.window('point',0,3999)
        self.assertEqual((w['left_cycle'],w['right_cycle'],w['left'],w['right']),(79781,79981,39890250000,39990250000))
        self.assertEqual((w['bytes'],w['events'],w['bpc']),(12800,200,F(64)))
        self.assertEqual(s.raw('point',0,79981)['total_bytes'],5118784)
        self.assertEqual(s.window_count('point',0),3999)

    def test_unknown_size_keeps_known_event_and_ancestor_subtotal(self):
        s=Scenario('common-ns-unknown')
        r=s.raw('group',0,201)
        self.assertEqual((r['byte_inc'],r['event_inc'],r['bytes_complete'],r['events_complete']),(256,5,0,1))
        self.assertEqual((s.window('group',0,11)['bytes'],s.window('group',0,11)['events']),(63936,1000))
        self.assertEqual(s.window('group',0,21)['bytes_complete'],1)

    def test_point_reset_changes_only_own_statistics_origin(self):
        s=Scenario('common-ns-reset')
        self.assertEqual(s.window_count('point',0),3999)
        self.assertEqual(s.raw('point',0,80000)['total_bytes'],5107072)
        self.assertEqual(s.raw('group',0,80000)['total_bytes'],25599872)
        self.assertEqual((s.window('group',0,11)['bytes'],s.window('group',0,11)['events'],s.window('group',0,11)['reset']),(63872,998,1))
        w=s.window('point',0,3999)
        self.assertEqual((w['epoch'],w['right'],w['left']),(1,39991100000,39891100000))

if __name__=='__main__':unittest.main()
