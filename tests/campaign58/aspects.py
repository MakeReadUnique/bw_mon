"""Ticket 58 campaign assets: fixed-input allocation, control table and the
criterion-four aspect mapping.

Every constant here is a statement of the already-adopted contract (decision 38
fixed inputs, decision 44 R2 repair counterexamples, tickets 51/52/53 product
cases). Nothing in this file relaxes a gate, adds a sweep or re-pins an input;
it only names which existing product cases carry each acceptance aspect so the
campaign can require them all to pass cold, serially, inside one 900 s budget.
"""

# Ticket criterion 1: four fixed inputs keep the frozen allocation from the
# behavior prototype. One elaboration per family, five points and one group.
FIXED_ALLOCATION = [
    {'id': 'continuous', 'name': '清晰连续变化', 'basis': 'ns',
     'stride': 'omitted(S=W)', 'q': 'omitted(10)', 'magnitudes': ['B', '2B'],
     'topology': '1 point + 4-member group', 'case': 'phase_fixed_continuous'},
    {'id': 'platforms', 'name': '波动平台', 'basis': 'cycle',
     'stride': 'omitted(S=W)', 'q': 'omitted(10)', 'magnitudes': ['B'],
     'topology': '1 point + 4-member group', 'case': 'phase_fixed_platforms'},
    {'id': 'activity', 'name': '活动与短过程', 'basis': 'cycle',
     'stride': 'explicit(1)', 'q': 'omitted(10)', 'magnitudes': ['B', '2B'],
     'topology': '1 point + 4-member group', 'case': 'phase_fixed_activity'},
    {'id': 'recovery', 'name': '证据中断与恢复', 'basis': 'ns',
     'stride': 'explicit(1)', 'q': 'omitted(10)', 'magnitudes': ['B', '2B'],
     'topology': '1 point + 4-member group', 'case': 'phase_fixed_recovery'},
]

FIXED_CASES = [family['case'] for family in FIXED_ALLOCATION]

# Ticket criterion 2: the complete episode/phase control table of decision 38.
CONTROL_TABLE = [
    {'episode': 0, 'phase': None, 'outcome': '战役内验证',
     'cases': ['phase_defaults'], 'note': 'no episode or phase analysis'},
    {'episode': 1, 'phase': None, 'outcome': '战役内验证',
     'cases': ['phase_defaults'], 'note': 'default joint episode+phase'},
    {'episode': 1, 'phase': 0, 'outcome': '战役内验证',
     'cases': ['phase_defaults'], 'note': 'episode only, phases disabled'},
    {'episode': 1, 'phase': 1, 'outcome': '战役内验证',
     'cases': ['phase_defaults'], 'note': 'explicit joint enable'},
    {'episode': 0, 'phase': 1, 'outcome': '配置错误（拒绝）',
     'cases': ['phase_config_episode'], 'note': 'illegal combination rejected'},
]

# Ticket criterion 2: shape/counterexample evidence rides the fixed inputs and
# the public ownership bench; every entry cites the carrying product cases.
JOINT_COVERAGE = {
    'clear_shapes': {
        'cases': ['phase_fixed_continuous'],
        'expectation': 'frozen R2 phase oracle via check.py'},
    'fluctuation': {
        'cases': ['phase_fixed_platforms'],
        'expectation': 'alternating +-2%/+-8% platforms stay STEADY; '
                       'joint 5% verdicts via check_ownership.py'},
    'activity_short': {
        'cases': ['phase_fixed_activity'],
        'expectation': 'pause/short burst/zero-byte/no-activity contract in '
                       'fixed.json and check.py'},
    'interruption_recovery': {
        'cases': ['phase_fixed_recovery'],
        'expectation': 'gap/reset/recovery targets re-accumulate without '
                       'stitching'},
    'r2_repair_counterexamples': {
        'cases': ['phase_fixed_continuous', 'phase_fixed_activity',
                  'phase_fixed_recovery', 'checker_ownership_five_reference',
                  'checker_ownership_early_fail', 'checker_ownership_crop',
                  'checker_ownership_crop_reset',
                  'checker_ownership_crop_truncated'],
        'expectation': 'normal-step proof, pause prefix retention, sustained '
                       'anomaly across short platforms, five-reference handoff, '
                       'early-fail retention and final-crop requalification'},
}

# Ticket criterion 4: each 5% aspect maps to cases whose independent
# expectations already exist; the campaign requires every one to pass.
FIVE_PERCENT_ASPECTS = {
    'equality': ['checker_numeric_low_equal', 'checker_numeric_high_equal',
                 'checker_numeric_expanded_high_equal'],
    'sustained_span': ['checker_numeric_dense_short',
                       'checker_numeric_dense_fail'],
    'reference_backcheck': ['checker_numeric_reference_backcheck'],
    'ownership_crop': ['checker_ownership_crop', 'checker_ownership_crop_reset',
                       'checker_ownership_crop_truncated'],
    'short_platform_old_evidence': ['checker_ownership_five_reference'],
    'early_fail': ['checker_ownership_early_fail'],
    'zero_nearzero': ['checker_numeric_zero', 'checker_numeric_nearzero',
                      'checker_numeric_nearzero_pass'],
    'no_process': ['checker_empty'],
    'rule_coexistence': ['checker_default_explicit',
                         'checker_numeric_explicit_time'],
    'dedup': ['checker_replay', 'checker_numeric_platform_replay',
              'checker_default_reset'],
}

CONTROL_CASES = sorted({case for row in CONTROL_TABLE
                        for case in row['cases']})


def campaign_cases():
    """Ordered, unique case list for one cold serial campaign run."""
    ordered = (FIXED_CASES + CONTROL_CASES +
               [case for cases in FIVE_PERCENT_ASPECTS.values()
                for case in cases])
    seen = set()
    result = []
    for case in ordered:
        if case not in seen:
            seen.add(case)
            result.append(case)
    return result
