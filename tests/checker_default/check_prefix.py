#!/usr/bin/env python3
"""Independent first-unknown-transfer/clean-later-platform input reference."""
import re
import sys
from fractions import Fraction
from pathlib import Path
text = Path(sys.argv[1]).read_text()
origin = int(re.search(r'BW_READY time_ticks=(\d+)', text).group(1))
rows = [dict(re.findall(r'(\w+)=([^ ]+)', line)) for line in text.splitlines()
        if line.startswith('BW_DEFAULT_CHECK ')]
assert len(rows) == 2
assert {(int(row['scope_kind']), row['scope']) for row in rows} == {
    (0, 'checker.prefix'), (1, 'checker.prefix')}
for row in rows:
    expected = dict(platform_start_ticks=origin+7000000, platform_end_ticks=origin+24500000,
                    check_start_ticks=origin+7000000, check_end_ticks=origin+24500000,
                    reference_valid=1, reference_count=6, reference_first_seq=8,
                    reference_last_seq=13, reference_first_u=origin+8000000,
                    reference_last_u=origin+13000000, reference_span=5000000,
                    samples=18, first_u=origin+7000000, last_u=origin+24000000,
                    quality_incomplete=0, platform_bytes_complete=1,
                    platform_start_known=1, platform_end_known=1, episode_bytes_complete=0)
    for key,value in expected.items():
        assert int(row[key]) == value, (key,row[key],value)
    assert row['reference_seqs'] == '8,9,10,11,12,13'
    assert row['B'] == '100' and row['threshold_gbps'] == '5'
    assert row['max_deviation_gbps'] == '0'
    # Seventeen known100B transfers after7ns, over17.5ns; first unknown
    # transfer at.5ns belongs to the episode prefix, outside this platform.
    assert float(row['steady_bandwidth_gbps']) == float(Fraction(3400,35))
    assert row['conclusion'] == 'PASS'
print('PASS independent clean-platform reference with unrelated unknown episode prefix')
