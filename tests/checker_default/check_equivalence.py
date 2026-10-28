#!/usr/bin/env python3
"""Compare independent compressed/split receipts from the same execution."""
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
rows = [dict(re.findall(r'(\w+)=([^ ]+)', line)) for line in text.splitlines()
        if line.startswith('BW_DEFAULT_CHECK ')]
assert len(rows) == 2
assert {row.pop('scope') for row in rows} == {'numeric.compressed', 'numeric.expanded'}
assert rows[0] == rows[1], (rows[0], rows[1])
assert rows[0]['B'] == '100'
assert rows[0]['threshold_gbps'] == '5'
assert rows[0]['reference_seqs'] == '1,2,3,4,5,6'
assert rows[0]['samples'] == '9'
if rows[0]['conclusion'] == 'PASS':
    assert rows[0]['max_deviation_gbps'] == '5'
    assert rows[0]['over_runs'] == '0'
else:
    assert rows[0]['conclusion'] == 'FAIL'
    assert rows[0]['max_deviation_gbps'] == '5.0999999999999943'
    assert rows[0]['longest_count'] == '2'
    assert rows[0]['longest_span'] == '10000000'
print('PASS exact compressed/split equivalence at and outside the strict five-percent boundary')
