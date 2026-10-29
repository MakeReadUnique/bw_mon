#!/usr/bin/env python3
"""Unit tests for the formal joint phase/5% campaign assets (ticket 58).

These tests cover the campaign's own logic: the aspect-to-case mapping, the
budget/stage accounting, and the joint results table assembly. They do not
re-run simulations; the cold campaign run is the end-to-end acceptance.
"""
import json
import math
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


class AspectMapping(unittest.TestCase):
    def test_fixed_allocation_matches_ticket(self):
        import aspects
        families = aspects.FIXED_ALLOCATION
        self.assertEqual({f['id'] for f in families},
                         {'continuous', 'platforms', 'activity', 'recovery'})
        by_id = {f['id']: f for f in families}
        # Two default S=W families (stride omitted) and two dense S=1 families
        # (explicit), covering both bases and both fixed byte magnitudes.
        self.assertEqual([by_id[i]['basis'] for i in
                          ('continuous', 'platforms', 'activity', 'recovery')],
                         ['ns', 'cycle', 'cycle', 'ns'])
        self.assertEqual([by_id[i]['stride'] for i in
                          ('continuous', 'platforms', 'activity', 'recovery')],
                         ['omitted(S=W)', 'omitted(S=W)', 'explicit(1)', 'explicit(1)'])
        for family in families:
            self.assertEqual(family['topology'], '1 point + 4-member group')
            self.assertEqual(family['q'], 'omitted(10)')
        magnitudes = {m for f in families for m in f['magnitudes']}
        self.assertEqual(len(magnitudes), 2, magnitudes)

    def test_five_percent_aspects_are_complete_and_unique(self):
        import aspects
        required = {'equality', 'sustained_span', 'reference_backcheck',
                    'ownership_crop', 'short_platform_old_evidence',
                    'early_fail', 'zero_nearzero', 'no_process',
                    'rule_coexistence', 'dedup'}
        self.assertEqual(set(aspects.FIVE_PERCENT_ASPECTS), required)
        seen = set()
        for aspect, cases in aspects.FIVE_PERCENT_ASPECTS.items():
            self.assertTrue(cases, aspect)
            for case in cases:
                self.assertNotIn(case, seen,
                                 'case used by two aspects: ' + case)
                seen.add(case)

    def test_control_table_is_the_five_row_contract(self):
        import aspects
        rows = aspects.CONTROL_TABLE
        self.assertEqual(len(rows), 5)
        self.assertEqual([(r['episode'], r['phase']) for r in rows],
                         [(0, None), (1, None), (1, 0), (1, 1), (0, 1)])
        self.assertEqual(rows[-1]['outcome'], 'configuration error')
        for row in rows[:-1]:
            self.assertEqual(row['outcome'], 'verified in campaign')

    def test_every_campaign_case_exists_in_cases_json(self):
        import aspects
        cases = {c['name'] for c in json.loads(
            (ROOT / 'tests/cases.json').read_text())}
        for name in aspects.campaign_cases():
            self.assertIn(name, cases, 'unknown campaign case ' + name)

    def test_campaign_cases_are_unique(self):
        import aspects
        cases = aspects.campaign_cases()
        self.assertEqual(len(cases), len(set(cases)))

    def test_fixed_input_files_exist_and_parse(self):
        import aspects
        fixed = json.loads(
            (ROOT / 'tests/phase_default/fixed.json').read_text())
        frozen_ids = {f['id'] for f in fixed['families']}
        for family in aspects.FIXED_ALLOCATION:
            self.assertIn(family['id'], frozen_ids)
            path = ROOT / 'tests/phase_default' / (family['id'] + '.txt')
            self.assertTrue(path.exists(), path)
            rows = [line.split() for line in
                    path.read_text().splitlines() if line.strip()]
            self.assertTrue(rows)
            for row in rows:
                self.assertEqual(len(row), 9, row)


class BudgetAccounting(unittest.TestCase):
    def test_stage_summary_sums_per_stage(self):
        import run
        entries = [{'stage': 'compile', 'seconds': 2.0},
                   {'stage': 'simulation', 'seconds': 1.5},
                   {'stage': 'compile', 'seconds': 3.0},
                   {'stage': 'verify', 'seconds': 0.5}]
        summary = run.stage_summary(entries)
        self.assertEqual(summary['compile'], 5.0)
        self.assertEqual(summary['simulation'], 1.5)
        self.assertEqual(summary['verify'], 0.5)
        self.assertEqual(set(summary), {'compile', 'simulation', 'verify'})

    def test_total_includes_every_measured_phase(self):
        import run
        report = {'lock_wait_seconds': 1.0, 'preparation_seconds': 2.0,
                  'table_seconds': 0.5, 'cleanup_seconds': 0.25,
                  'commands': [{'stage': 'compile', 'seconds': 4.0},
                               {'stage': 'simulation', 'seconds': 2.0},
                               {'stage': 'verify', 'seconds': 0.5}]}
        total = run.campaign_total_seconds(report)
        self.assertAlmostEqual(total, 1.0 + 2.0 + 0.5 + 0.25 + 4.0 + 2.0 + 0.5)

    def test_within_budget_uses_measured_total(self):
        import run
        report = {'total_seconds': 899.9, 'budget_seconds': 900}
        self.assertTrue(run.within_budget(report))
        report['total_seconds'] = 900.0
        self.assertTrue(run.within_budget(report))
        report['total_seconds'] = 900.1
        self.assertFalse(run.within_budget(report))

    def test_child_timeout_never_exceeds_remaining_budget(self):
        import run
        deadline = 1000.0
        self.assertEqual(run.clamp_timeout(50.0, deadline, 990.0), 10.0)
        self.assertEqual(run.clamp_timeout(50.0, deadline, 995.0), 5.0)
        self.assertEqual(run.clamp_timeout(50.0, deadline, 1001.0), 0.0)


class JointTable(unittest.TestCase):
    @staticmethod
    def sample_family():
        return {'id': 'continuous', 'name': '清晰连续变化', 'basis': 'ns',
                'w': 10, 's': 10, 'q': 10,
                'cases': [{'id': 1, 'name': '恒定阶跃下降爬坡及重复平台',
                           'targets': [{'key': 'c1', 'inputU': 20,
                                        'first': 31, 'boundary': 30,
                                        'confirmation': 37, 'deadline': 38}],
                           'phases': []}]}

    def test_target_row_reports_both_latencies(self):
        import joint
        target = {'case': 1, 'kind': 'point', 'target': 'c1',
                  'first_ticks': 31_000_001, 'boundary_ticks': 30_000_001,
                  'confirmation_ticks': 37_000_001, 'updates': 7,
                  'seven_stride_ticks': 70_000_000,
                  'first_to_confirmation_ticks': 6_000_000,
                  'input_to_confirmation_ticks': 16_000_000}
        row = joint.target_row(self.sample_family(), target)
        # Independent worked example: first full window reflecting the shape
        # publishes at 31ns, confirmation at 37ns -> 6ns latency; the input
        # changed at u=20 (20ns +1fs drive point), so 37ns-20.000001us=16.999999us
        # is wrong; the recorded value 16us must be preserved verbatim.
        self.assertEqual(row['first_to_confirmation_ns'], 6.0)
        self.assertEqual(row['input_to_confirmation_ns'], 16.0)
        self.assertEqual(row['updates_within_deadline'], 7)
        self.assertTrue(row['within_eighth_update'])
        row2 = joint.target_row(self.sample_family(), dict(target, updates=8))
        self.assertTrue(row2['within_eighth_update'])
        row3 = joint.target_row(self.sample_family(), dict(target, updates=9))
        self.assertFalse(row3['within_eighth_update'])

    def test_check_row_pairs_expected_with_actual(self):
        import joint
        actual = {'conclusion': 'FAIL', 'reason': 'SUSTAINED_EXCEEDANCE',
                  'B': '100', 'samples': '12', 'longest_count': '12',
                  'longest_span': '11000000', 'platform': '1',
                  'reference_seqs': '7,8,9,10,11,12'}
        row = joint.check_row(1, 'point', 0, actual, 'FAIL')
        self.assertEqual(row['expected'], 'FAIL')
        self.assertEqual(row['actual'], 'FAIL')
        self.assertEqual(row['difference'], '')
        mismatch = joint.check_row(1, 'point', 0, actual, 'PASS')
        self.assertEqual(mismatch['difference'], 'expected PASS actual FAIL')

    def test_family_table_marks_wrong_confirmations_and_switches(self):
        import joint
        table = joint.family_table(
            self.sample_family(),
            targets=[{'case': 1, 'kind': 'point', 'target': 'c1',
                      'first_ticks': 1, 'boundary_ticks': 1,
                      'confirmation_ticks': 1, 'updates': 7,
                      'seven_stride_ticks': 1,
                      'first_to_confirmation_ticks': 1,
                      'input_to_confirmation_ticks': 1}],
            checks=[{'case': 1, 'kind': 'point', 'platform': 1,
                     'expected': 'FAIL',
                     'actual': {'conclusion': 'FAIL', 'reason': 'x',
                                'B': '100', 'samples': '1',
                                'longest_count': '1',
                                'longest_span': '1', 'platform': '1',
                                'reference_seqs': '1,2,3,4,5,6'}}],
            phases_verified=True)
        self.assertEqual(table['wrong_confirmations'], 0)
        self.assertEqual(table['extra_switches'], 0)
        self.assertEqual(len(table['targets']), 1)
        self.assertEqual(len(table['checks']), 1)
        self.assertEqual(table['differences'], [])

    def test_family_table_collects_differences(self):
        import joint
        table = joint.family_table(
            self.sample_family(), targets=[],
            checks=[{'case': 1, 'kind': 'point', 'platform': 2,
                     'expected': 'PASS',
                     'actual': {'conclusion': 'WARNING', 'reason': 'y',
                                'B': 'UNAVAILABLE', 'samples': '0',
                                'longest_count': '0',
                                'longest_span': '0', 'platform': '2',
                                'reference_seqs': ''}}],
            phases_verified=True)
        self.assertEqual(len(table['differences']), 1)
        self.assertIn('expected PASS actual WARNING', table['differences'][0])


class ExactBaseline(unittest.TestCase):
    @staticmethod
    def window(bytes_, right_ns, left_ns):
        class Window(object):
            pass
        window = Window()
        window.bytes = bytes_
        window.ticks = right_ns * 1_000_000
        window.left = left_ns * 1_000_000
        return window

    def test_exact_baseline_is_exact_rational_arithmetic(self):
        import joint
        from fractions import Fraction
        baseline = joint.exact_baseline(
            [self.window(100, 10, 0)] * 6)
        self.assertEqual(baseline, Fraction(10))
        self.assertEqual(float(baseline), 10.0)
        mixed = joint.exact_baseline(
            [self.window(10, 10, 0)] * 3 + [self.window(11, 10, 0)] * 3)
        self.assertEqual(mixed, Fraction(21, 20))

    def test_exact_baseline_handles_repeating_decimals(self):
        import joint
        from fractions import Fraction
        baseline = joint.exact_baseline([self.window(1, 3, 0)] * 6)
        self.assertEqual(baseline, Fraction(1, 3))
        self.assertLess(abs(float(baseline) - 1.0 / 3.0), 1e-12)

    def test_baseline_agrees_within_tolerance(self):
        import joint
        self.assertTrue(joint.baseline_agrees('100', 100.0))
        self.assertTrue(joint.baseline_agrees('0.3333333333333333',
                                              1.0 / 3.0))
        self.assertFalse(joint.baseline_agrees('100.5', 100.0))
        self.assertFalse(joint.baseline_agrees('UNAVAILABLE', 100.0))


class AspectAggregation(unittest.TestCase):
    def test_aspect_status_fails_on_any_failed_case(self):
        import run
        outcomes = {'checker_numeric_zero': True, 'checker_numeric_nearzero': False}
        self.assertFalse(run.aspect_passed(['checker_numeric_zero',
                                            'checker_numeric_nearzero'],
                                           outcomes))
        self.assertTrue(run.aspect_passed(['checker_numeric_zero'], outcomes))

    def test_aspect_status_fails_on_missing_case(self):
        import run
        self.assertFalse(run.aspect_passed(['checker_empty'], {}))

    def test_aspect_report_lists_each_criterion_four_aspect(self):
        import aspects
        import run
        report = run.aspect_report({'phase_fixed_continuous': True})
        keys = {entry['aspect'] for entry in report}
        self.assertEqual(keys, set(aspects.FIVE_PERCENT_ASPECTS))
        for entry in report:
            self.assertTrue(entry['status'].startswith('FAILED:'),
                            entry['status'])


if __name__ == '__main__':
    unittest.main()
