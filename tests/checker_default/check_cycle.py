#!/usr/bin/env python3
"""Derive cycle-check expectations from the edge/byte input schedule only."""
import re
import sys
from fractions import Fraction
from pathlib import Path

text = Path(sys.argv[1]).read_text()
constant = sys.argv[2] == 'constant'
origin = int(re.search(r'BW_READY time_ticks=(\d+)', text).group(1))
ticks, sizes = {}, {}
tick = origin + 500000
for edge in range(1, 30):
    ticks[edge] = tick
    period = 20 if edge == 15 else (2 if edge >= 12 else 1)
    sizes[edge] = (100 if constant else (92 if edge % 2 else 108)) * period
    tick += period * 1000000
rows = [dict(re.findall(r'(\w+)=([^ ]+)', line)) for line in text.splitlines()
        if line.startswith('BW_DEFAULT_CHECK ')]
assert len(rows) == 2
assert {(int(row['scope_kind']), row['scope']) for row in rows} == {
    (0, 'checker.cycle'), (1, 'checker.cycle')}
for row in rows:
    expected = dict(basis=1, W=1, S=1, platform=1, episode=1, epoch=0,
                    platform_start_ticks=ticks[7], platform_end_ticks=ticks[25],
                    check_start_ticks=ticks[7], check_end_ticks=ticks[25],
                    reference_first_seq=7, reference_last_seq=12,
                    reference_first_u=8, reference_last_u=13, reference_span=5,
                    reference_count=6, reference_valid=1, samples=18,
                    first_u=7, last_u=24, quality_incomplete=0,
                    longest_count=0 if constant else 18,
                    longest_first_u=0 if constant else 7,
                    longest_last_u=0 if constant else 24,
                    longest_span=0 if constant else 17)
    for key, value in expected.items():
        assert int(row[key]) == value, (key, row[key], value)
    assert row['reference_seqs'] == '7,8,9,10,11,12'
    assert float(row['B']) == 100
    assert float(row['threshold_gbps']) == 5
    assert float(row['max_deviation_gbps']) == (0 if constant else 8)
    raw = Fraction(sum(sizes[edge] for edge in range(7, 25)) * 1000000,
                   ticks[25] - ticks[7])
    assert float(row['steady_bandwidth_gbps']) == float(raw), row
    assert row['conclusion'] == ('PASS' if constant else 'FAIL')
print('PASS independent changing-frequency/stopped-clock cycle reference')
