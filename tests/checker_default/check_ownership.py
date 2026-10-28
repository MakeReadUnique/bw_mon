#!/usr/bin/env python3
"""Joint product check: unchanged R2 protocol inputs and frozen phase oracle."""
import json
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"phase_default"))
from check import check, fields
from window_reference import reference_family

log,family=sys.argv[1:]
check(log,family)
frozen=json.loads((Path(__file__).resolve().parents[1]/"phase_default/fixed.json").read_text())
configuration=next(f for f in frozen['families'] if f['id']==family)
references=reference_family(configuration)
# Literal earliest reference endpoints from the adopted intervals. The expected
# values/geometry below come from original protocol sums, not product windows.
ref_starts={1:[70,230,540,850],2:[70,190],3:[70],4:[70],5:[70,310],
            6:[25,None,108],7:[None],8:[25],10:[25,96,185],
            11:[25,106,197],12:[25,151],13:[25,None,None,None,177]}
cycle_offsets={};edge_count=0
for case in configuration["cases"]:
    cycle_offsets[case["id"]]=edge_count+1;edge_count+=len(case["rows"])
sequence_offset={};offset=0
for cid,reference in references.items():
    sequence_offset[cid]=offset;offset+=len(reference.windows)
current=None
results={}
steps={}
handoffs={}
for line in Path(log).read_text().splitlines():
    v=fields(line)
    if line.startswith("FIXED_CASE "):current=int(v["case"])
    if line.startswith(("BW_STAGE_STEP ","BW_STAGE_HANDOFF ")) and v["scope"].startswith("phase.fixed."):
        kind="point" if ".point" in v["scope"] else "group"
        (steps if line.startswith("BW_STAGE_STEP ") else handoffs).setdefault((current,kind),[]).append(v)
    if line.startswith("BW_DEFAULT_CHECK ") and v["scope"].startswith("phase.fixed."):
        kind="point" if ".point" in v["scope"] else "group"
        results.setdefault((current,kind),[]).append(v)
# Literal verdicts and handoff targets come from adopted R2 cases. Physical
# NS endpoints in the public harness are 1fs before the last cycle tail: case2
# therefore contains the sixth reference window and legitimately passes. The
# endpoint-aligned five-window counterpart has separate public coverage.
expected={1:["PASS"]*4,2:["PASS","PASS"],3:["PASS"],4:["FAIL"],
          5:["FAIL","PASS"],6:["FAIL","WARNING","PASS"],7:["WARNING"],
          8:["WARNING"],10:["PASS"]*3,11:["WARNING","WARNING","PASS"],
          12:["PASS","PASS"],13:["FAIL","WARNING","WARNING","WARNING","PASS"]}
for (cid,kind),rows in results.items():
    assert [v["conclusion"] for v in rows]==expected[cid],(cid,kind,rows)
    reference=references[cid]
    by_u={w.u:(i+1+sequence_offset[cid],w) for i,w in enumerate(reference.windows)}
    for i,v in enumerate(rows):
        start=ref_starts[cid][i]
        if start is None:
            assert v['reference_valid']=='0',v
            continue
        selected=[by_u[start+j*configuration['s']] for j in range(6)]
        assert v['reference_seqs']==','.join(str(seq) for seq,w in selected),(cid,kind,v,selected)
        assert float(v['B'])==sum(w.y for seq,w in selected)/6,(cid,kind,v,selected)
        assert int(v['reference_first_u'])==(selected[0][1].u+cycle_offsets[cid] if configuration['basis']=='cycle' else selected[0][1].ticks),v
        assert int(v['reference_last_u'])==(selected[-1][1].u+cycle_offsets[cid] if configuration['basis']=='cycle' else selected[-1][1].ticks),v
        for seq,w in selected:
            assert w.eligible and w.left>=int(v['platform_start_ticks']) and w.ticks<int(v['platform_end_ticks']),(cid,kind,seq,w)
    if cid==1:
        step=steps[(cid,kind)][0];T=reference.origin
        for key,value in {'valid':1,'old_support_first':1,'old_support_last':7,
                          'new_support_first':17,'new_support_last':23,
                          'bridge_first_seq':16,'bridge_last_seq':17,
                          'bridge_start':T+160_000_000,'bridge_end':T+170_000_000,
                          'bridge_span':10_000_000,'arrived_ticks':T+170_000_000,
                          'exclusion_start_ticks':T+170_000_000,'exclusion_end_ticks':T+220_000_000,
                          'retained_start_ticks':T+60_000_000,'retained_end_ticks':T+170_000_000}.items():
            assert int(step[key])==value,(kind,key,step)
        assert [float(step[k]) for k in ('old_min','old_max','new_min','new_max')]==[100,100,200,200],step
    if cid in (6,13):
        short=(1,) if cid==6 else (1,2,3)
        for i in short:
            assert handoffs[(cid,kind)][i]['valid']=='0',handoffs[(cid,kind)][i]
        target=98 if cid==6 else 167
        assert int(rows[0]['check_end_ticks'])==next(w.ticks for w in reference.windows if w.u==target),rows[0]
    if cid==6:
        v=rows[0]
        assert (int(v["longest_count"]),int(v["longest_span"]))==(12,11),v
    if cid==13:
        v=rows[0]
        assert (int(v["longest_count"]),int(v["longest_span"]))==(46,45*1_000_000),v
print("OWNERSHIP_PASS",family)
