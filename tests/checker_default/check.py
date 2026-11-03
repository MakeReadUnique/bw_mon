#!/usr/bin/env python3
"""Independent raw-input reference for the single-platform public fixture."""
import re
import sys
from fractions import Fraction
from pathlib import Path

text = Path(sys.argv[1]).read_text()
origin = int(re.search(r'BW_READY time_ticks=(\d+)', text).group(1))
alternating = sys.argv[2] == 'alternating'
rows = [dict(re.findall(r'(\w+)=([^ ]+)', line)) for line in text.splitlines()
        if line.startswith('BW_DEFAULT_CHECK ')]
assert len(rows) == 5, len(rows)
expected_ids = {(0, 'checker.p%d' % member) for member in range(4)} | {(1, 'checker.group')}
assert {(int(row['scope_kind']), row['scope']) for row in rows} == expected_ids
# Raw schedule: one transfer at n-.5 ns, publication at n ns; W=S=1.
# Real PAIR6 boundary is publication six; next edge after transfer 24 ends
# the episode at 24.5. Fully contained reference starts at publication seven.
for row in rows:
    scale = 4 if row['scope_kind'] == '1' else 1
    expected = dict(epoch=0, episode=1, platform=1, basis=0, W=1, S=1,
                    platform_start_ticks=origin + 6000000,
                    platform_end_ticks=origin + 24500000,
                    check_start_ticks=origin + 6000000,
                    check_end_ticks=origin + 24500000,
                    reference_valid=1, reference_count=6,
                    reference_first_seq=7, reference_last_seq=12,
                    reference_first_u=origin + 7000000,
                    reference_last_u=origin + 12000000, reference_span=5000000,
                    samples=19, first_u=origin + 6000000, last_u=origin + 24000000,
                    quality_incomplete=0, over_runs=1 if alternating else 0,
                    longest_count=19 if alternating else 0,
                    longest_first_u=origin + 6000000 if alternating else 0,
                    longest_last_u=origin + 24000000 if alternating else 0,
                    longest_span=18000000 if alternating else 0)
    for key, value in expected.items():
        assert int(row[key]) == value, (row['scope'], key, row[key], value)
    assert row['reference_seqs'] == '7,8,9,10,11,12'
    assert float(row['B']) == 100 * scale
    assert float(row['threshold_gbps']) == 5 * scale
    assert float(row['max_deviation_gbps']) == (8 if alternating else 0) * scale
    assert float(row['max_deviation_pct']) == (8 if alternating else 0)
    # Eighteen transfers after boundary six, divided by 18.5ns: separate from B.
    raw_bandwidth = Fraction(1800 * scale, 1) / Fraction(37, 2)
    assert float(row['steady_bandwidth_gbps']) == float(raw_bandwidth)
    assert row['conclusion'] == ('FAIL' if alternating else 'PASS')
print('PASS independent raw single-platform reference: five typed point/group results')
