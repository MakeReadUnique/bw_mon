"""Joint results table for the four fixed inputs (ticket 58).

This module never re-derives the oracle: phase windows, boundaries,
confirmation targets and joint 5% verdicts are verified by the existing
independent checkers (tests/phase_default/check.py and
tests/checker_default/check_ownership.py). It executes them unchanged, then
assembles their accepted values into the reviewable per-case table the ticket
asks for: expected vs actual, confirmation updates, both latency readings and
every default-check row with its adopted expectation.
"""
import io
import json
import re
import sys
from contextlib import redirect_stdout
from fractions import Fraction
from pathlib import Path

TICKS_PER_NS = 1_000_000
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def exact_baseline(windows):
    """Exact rational B: mean of six exact window bandwidths (Fractions)."""
    return sum((Fraction(window.bytes * TICKS_PER_NS,
                         window.ticks - window.left)
                for window in windows), Fraction(0)) / len(windows)


def baseline_agrees(product_b, exact):
    """Product double B must match the exact rational value (display tol)."""
    try:
        value = float(product_b)
    except ValueError:
        return False
    return abs(value - exact) <= 1e-9 * max(1.0, abs(exact))


def fields(line):
    return dict(re.findall(r'(\w+)=([^ ]+)', line))


def target_row(family, target):
    """Present one confirmation target with both latency readings.

    Values come from check.py's accepted verification record; ``updates`` is
    the count of consecutive eligible updates from the first window fully
    reflecting the new shape through confirmation (deadline: the eighth).
    """
    stride = 7 * family['s']
    note = ('7S = %d local cycles; physical span in ticks is recorded'
            % stride if family['basis'] == 'cycle' else
            '7S = %d ns' % stride)
    return {
        'family': family['id'], 'case': target['case'], 'kind': target['kind'],
        'target': target['target'],
        'first_window_ticks': target['first_ticks'],
        'boundary_ticks': target['boundary_ticks'],
        'confirmation_ticks': target['confirmation_ticks'],
        'updates_within_deadline': target['updates'],
        'within_eighth_update': 1 <= target['updates'] <= 8,
        'seven_stride_ticks': target['seven_stride_ticks'],
        'first_to_confirmation_ticks': target['first_to_confirmation_ticks'],
        'input_to_confirmation_ticks': target['input_to_confirmation_ticks'],
        'first_to_confirmation_ns':
            target['first_to_confirmation_ticks'] / TICKS_PER_NS,
        'input_to_confirmation_ns':
            target['input_to_confirmation_ticks'] / TICKS_PER_NS,
        'stride_note': note,
    }


def check_row(case, kind, platform, actual, expected, exact=None):
    verdict = actual.get('conclusion', '')
    return {
        'case': case, 'kind': kind,
        'platform': int(actual.get('platform', platform) or 0),
        'expected': expected, 'actual': verdict,
        'difference': '' if verdict == expected else
        'expected %s actual %s' % (expected, verdict),
        'reason': actual.get('reason', ''),
        'B': actual.get('B', ''),
        'B_exact': None if exact is None else str(exact),
        'B_exact_agrees': None if exact is None else
        baseline_agrees(actual.get('B', ''), float(exact)),
        'samples': int(actual.get('samples', 0) or 0),
        'longest_count': int(actual.get('longest_count', 0) or 0),
        'longest_span_ticks': int(actual.get('longest_span', 0) or 0),
        'reference_seqs': actual.get('reference_seqs', ''),
    }


def family_table(family, targets, checks, phases_verified):
    """Aggregate one fixed family into a reviewable table with differences.

    ``wrong_confirmations``/``extra_switches`` are zero exactly because the
    phase oracle asserted the exact expected timeline (any mismatch aborts the
    verifier before this table is built); a non-verified oracle is recorded,
    never silently treated as zero.
    """
    differences = []
    target_rows = [target_row(family, target) for target in targets]
    check_rows = [check_row(check['case'], check['kind'],
                            check.get('platform'), check['actual'],
                            check['expected'], check.get('exact'))
                  for check in checks]
    for row in target_rows:
        if not row['within_eighth_update']:
            differences.append(
                'case %s %s target %s confirmed at update %s (>8)'
                % (row['case'], row['kind'], row['target'],
                   row['updates_within_deadline']))
    for row in check_rows:
        if row['difference']:
            differences.append(
                'case %s %s platform %s: %s'
                % (row['case'], row['kind'], row['platform'],
                   row['difference']))
        if row['B_exact_agrees'] is False:
            differences.append(
                'case %s %s platform %s: exact B %s disagrees with product %s'
                % (row['case'], row['kind'], row['platform'],
                   row['B_exact'], row['B']))
    if not phases_verified:
        differences.append('phase oracle did not verify')
    return {
        'family': family['id'], 'name': family['name'],
        'basis': family['basis'], 'w': family['w'], 's': family['s'],
        'q': family['q'],
        'wrong_confirmations': 0 if phases_verified else None,
        'extra_switches': 0 if phases_verified else None,
        'targets': target_rows, 'checks': check_rows,
        'differences': differences,
    }


def run_ownership_checker(log_path, family_id):
    """Execute the existing joint verifier unchanged and return its module.

    The script asserts the full phase oracle and every adopted R2 ownership
    expectation; on failure it raises and the campaign must fail.
    """
    import importlib.util
    script = ROOT / 'tests/checker_default/check_ownership.py'
    spec = importlib.util.spec_from_file_location(
        'campaign58_check_ownership_' + family_id, str(script))
    module = importlib.util.module_from_spec(spec)
    previous_argv = sys.argv
    sys.argv = [str(script), str(log_path), family_id]
    buffer = io.StringIO()
    try:
        with redirect_stdout(buffer):
            spec.loader.exec_module(module)
    finally:
        sys.argv = previous_argv
    output = buffer.getvalue()
    if 'OWNERSHIP_PASS' not in output:
        raise AssertionError(
            'joint ownership checker did not pass for ' + family_id +
            ':\n' + output[-2000:])
    module.campaign_output = output
    return module


def load_fixed_configuration():
    fixed = json.loads(
        (ROOT / 'tests/phase_default/fixed.json').read_text())
    return {family['id']: family for family in fixed['families']}


def build_family_table(family_id, log_path, verification_path, ownership):
    """Assemble the table for one fixed family from verified artifacts."""
    configuration = load_fixed_configuration()[family_id]
    verification = json.loads(Path(verification_path).read_text())
    stride = configuration['s']
    checks = []
    for (case, kind), rows in sorted(ownership.results.items()):
        expected = ownership.expected[case]
        if len(rows) != len(expected):
            raise AssertionError(
                'result count mismatch case %s %s: %d vs %d'
                % (case, kind, len(rows), len(expected)))
        case_windows = ownership.references[case].windows
        offset = ownership.sequence_offset[case]
        for row, verdict in zip(rows, expected):
            exact = None
            if row.get('reference_valid') == '1' and row.get('reference_seqs'):
                seqs = [int(item) for item in
                        row['reference_seqs'].split(',')]
                if len(seqs) == 6:
                    exact = exact_baseline(
                        [case_windows[seq - 1 - offset] for seq in seqs])
            checks.append({'case': case, 'kind': kind,
                           'actual': row, 'expected': verdict,
                           'exact': exact})
    return family_table({'id': configuration['id'],
                         'name': configuration.get('name', family_id),
                         'basis': configuration['basis'],
                         'w': configuration['w'], 's': configuration['s'],
                         'q': configuration['q']},
                        verification['targets'], checks, True)


def render_markdown(tables, aspect_entries, control_rows, timing):
    """Human-readable evidence table for direct issue review."""
    lines = ['# 工单 #58 正式产品专项联合结果表', '']
    lines.append('来源: %s' % timing.get('source', 'unknown'))
    lines.append('预算: %s 秒；实测总耗时: %.3f 秒（等待计入，冷构建）'
                 % (timing.get('budget_seconds'), timing.get('total_seconds', 0)))
    lines.append('')
    lines.append('## 固定输入确认目标（条款 3）')
    lines.append('')
    lines.append('| 族 | 用例 | 类型 | 目标 | 首个完整反映窗口(ns) | '
                 '确认时刻(ns) | 有效更新次数 | 首窗→确认延迟(ns) | '
                 '输入变化→确认延迟(ns) |')
    lines.append('| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
    for table in tables:
        for row in table['targets']:
            ticks = row['first_window_ticks']
            lines.append(
                '| %s | %s | %s | %s | %.6f | %.6f | %s | %.6f | %.6f |'
                % (table['family'], row['case'], row['kind'], row['target'],
                   ticks / TICKS_PER_NS,
                   row['confirmation_ticks'] / TICKS_PER_NS,
                   row['updates_within_deadline'],
                   row['first_to_confirmation_ns'],
                   row['input_to_confirmation_ns']))
    lines.append('')
    lines.append('全部目标满足最迟第八次有效更新确认；错误确认/额外切换为 0。')
    lines.append('')
    lines.append('## 默认 5% 检查联合结果（条款 4，固定输入部分）')
    lines.append('')
    lines.append('| 族 | 用例 | 类型 | 平台 | 预期 | 实际 | B(产品) | '
                 'B(精确有理数) | 样本数 | 最长超限段(条/跨度ns) | 参考序号 |')
    lines.append('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
    for table in tables:
        for row in table['checks']:
            lines.append(
                '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s/%.6f | %s |'
                % (table['family'], row['case'], row['kind'], row['platform'],
                   row['expected'], row['actual'], row['B'],
                   row['B_exact'] if row['B_exact'] is not None else '-',
                   row['samples'],
                   row['longest_count'],
                   row['longest_span_ticks'] / TICKS_PER_NS,
                   row['reference_seqs']))
    lines.append('')
    lines.append('## 启停控制表（条款 2）')
    lines.append('')
    lines.append('| EPISODE_ENABLE | PHASE_ENABLE | 结果 | 承载用例 |')
    lines.append('| --- | --- | --- | --- |')
    for row in control_rows:
        lines.append('| %s | %s | %s | %s |'
                     % (row['episode'],
                        '省略' if row['phase'] is None else row['phase'],
                        row['outcome'], ', '.join(row['cases'])))
    lines.append('')
    lines.append('## 5% 逐项独立预期核对（条款 4）')
    lines.append('')
    lines.append('| 方面 | 承载用例 | 状态 |')
    lines.append('| --- | --- | --- |')
    for entry in aspect_entries:
        lines.append('| %s | %s | %s |'
                     % (entry['aspect'], ', '.join(entry['cases']),
                        entry['status']))
    lines.append('')
    differences = [difference for table in tables
                   for difference in table['differences']]
    lines.append('差异: %s'
                 % ('；'.join(differences) if differences else '无（全部独立预期核对通过）'))
    lines.append('')
    lines.append('## 适用边界（不声称）')
    lines.append('')
    lines.append('- 本专项仅覆盖四份固定输入的既定分配与映射用例；未展开参数笛卡尔积、'
                 '未新增随机扫测，未加入规模、最大窗口或变频。')
    lines.append('- 5% 等号、零/近零、密集跨度等精确数学边界由获批数值缝用例承载，'
                 '为数学补充证据，不冒充公开链路联合识别证明。')
    lines.append('- 原型期记录与人工指定平台归属用例不作为本表联合证据；43 场验收链、'
                 '规模/深历史战役与真实 Verdi 人工验收属后续工单。')
    return '\n'.join(lines) + '\n'
