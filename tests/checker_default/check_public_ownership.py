#!/usr/bin/env python3
"""Exact raw fixture endpoints and literal recognition expectations."""
import re,sys
from pathlib import Path

def fields(s):return dict(re.findall(r'(\w+)=([^ ]+)',s))
lines=Path(sys.argv[1]).read_text().splitlines();mode=sys.argv[2]
T=int(next(fields(l)['time_ticks'] for l in lines if l.startswith('BW_READY ')))
for kind in ('0','1'):
    rows=[fields(l) for l in lines if l.startswith('BW_DEFAULT_CHECK ') and fields(l)['scope_kind']==kind]
    phases=[fields(l) for l in lines if l.startswith('BW_PHASE ') and fields(l)['scope_kind']==kind]
    steps=[fields(l) for l in lines if l.startswith('BW_STAGE_STEP ') and fields(l)['scope_kind']==kind]
    if mode.startswith('member_'):
        assert [r['conclusion'] for r in rows]==(['PASS','WARNING'] if kind=='0' else
          (['FAIL','WARNING'] if mode=='member_reset' else ['FAIL'])),(mode,kind,rows)
        if kind=='1':
            if mode=='member_reset':
                qualifications=[fields(l) for l in lines if l.startswith('BW_STAGE_HANDOFF ') and fields(l)['scope_kind']==kind]
                assert qualifications[-1]['valid']=='1' and int(qualifications[-1]['span'])==10_000_000,qualifications
                assert int(rows[0]['check_end_ticks'])==T+180_000_000,rows[0]
                assert rows[0]['handoff_platform']!='0' and steps[0]['valid']=='0',(rows,steps)
            else:
                assert rows[0]['handoff_platform']=='0' and rows[0]['quality_incomplete']=='1',rows
        continue
    assert len(rows)==2,(mode,kind,rows)
    if mode=='five':
        assert [r['conclusion'] for r in rows]==['PASS','WARNING'],rows
        assert [int(r['platform_start_ticks'])-T for r in rows]==[60_000_000,180_000_000],rows
        assert int(rows[1]['platform_end_ticks'])==T+240_000_000,rows[1]
        assert int(rows[1]['reference_count'])==5 and rows[1]['reference_valid']=='0',rows[1]
        assert int(rows[0]['check_end_ticks'])==T+180_000_000 and rows[0]['handoff_platform']!='0',rows[0]
        assert steps[0]['valid']=='1',steps
        assert rows[1]['reference_seqs']=='19,20,21,22,23',rows[1]
        qualification=[fields(l) for l in lines if l.startswith('BW_STAGE_HANDOFF ') and fields(l)['scope_kind']==kind][1]
        assert qualification['valid']=='1' and int(qualification['first_u'])==T+180_000_000 and int(qualification['last_u'])==T+190_000_000,qualification
    elif mode=='late_reset':
        assert [r['conclusion'] for r in rows]==['PASS','WARNING'],rows
        assert rows[0]['handoff_platform']!='0',rows
        assert steps[0]['valid']=='1',steps
    elif mode=='early':
        assert [r['conclusion'] for r in rows]==['FAIL','PASS'],rows
        assert int(rows[0]['longest_count'])==2 and int(rows[0]['longest_span'])==10_000_000,rows[0]
        assert int(rows[0]['longest_first_u'])==T+130_000_000 and int(rows[0]['longest_last_u'])==T+140_000_000,rows[0]
        assert steps[0]['valid']=='1' and int(steps[0]['exclusion_start_ticks'])==T+170_000_000,steps
    else:
        assert rows[0]['handoff_platform']=='0',rows
        assert int(rows[0]['check_end_ticks'])==T+(99_000_001 if mode=='reset' else 100_000_000),rows
        assert [r['conclusion'] for r in rows]==['FAIL','WARNING'],rows
        assert int(rows[0]['longest_first_u'])==T+49_000_000 and int(rows[0]['longest_last_u'])==T+61_000_000,rows[0]
        assert int(rows[0]['longest_count'])==13 and int(rows[0]['longest_span'])==12_000_000,rows[0]
        assert int(rows[1]['platform_start_ticks'])==T+94_000_000,rows[1]
        assert int(rows[1]['platform_end_ticks'])==T+100_000_000,rows[1]
print('PUBLIC_OWNERSHIP_PASS',mode)
