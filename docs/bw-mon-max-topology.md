# Maximum-topology correctness and resources

The fixed profiles in `tests/scale/maximum.py` reuse the public-module generator,
independent leaf-set/clock reference and every-receipt/window checker documented
in [the scale harness](bw-mon-scale.md). They address [maximum topology
acceptance](https://github.com/MakeReadUnique/bw_mon/issues/30). Native profiles
always request 16,384 points, 4,096 group owners and exactly 40us; the wrapper has
no reduced-count or reduced-duration override.

```sh
python3 tests/scale/test_reference.py
python3 tests/scale/test_maximum.py
python3 tests/scale/maximum.py max-tracer-ns max-tracer-cycle max-tracer-unknown max-tracer-reset
python3 tests/scale/maximum.py max-ns max-cycle max-ns-short-unknown max-cycle-short-reset --output-root /path/to/evidence
```

Every native profile uses the same independently checked, recursively disjoint
graph. Every group has 16 direct members, giving 65,536 edges. Groups0 through7
form a depth-eight chain: group0 has 16 points; each next level adds 15 fresh
points. Group7 therefore contains 121 recursive points. Fifteen other groups
include point0, so that point has exactly sixteen direct parents. Remaining
groups use bounded point reuse. Point16383 is ungrouped and remains included in
the expected total and every local check. Recursive cardinalities are16 for4089
groups, then31/46/61/76/91/106/121 for the seven upper chain groups. The graph
SHA256 is `736a6660a63a4596fe2d41e45e241c4024c98c05957c13f297b31f0b67a7f2a3`.

The manifests retain every typed direct edge and every independent recursive leaf
set. A group's registered counts are observations to compare with this input,
never oracle inputs. Points keep the default full hierarchy identity
`tb_bw_scale.points[N].slot.mon`; group IDs are explicitly `scale.gN`, owned at
`tb_bw_scale.groups[N].slot.mon`. Explicit Group IDs are required by the public
module. Every scope is an actual public module, with the unified setup and
automatic collectors; the test never manually forwards or acknowledges frames.

| Native profile | Basis, W/S | Intervention | Expected window checks |
| --- | --- | --- | ---: |
|max-ns |ns100/10 |none |81,920,000 |
|max-cycle |cycle200/20 |none |81,899,520 |
|max-ns-short-unknown |ns10/10 |p0 sizeX at100.25ns |81,920,000 |
|max-cycle-short-reset |cycle20/20 |p0 reset[100.1,101.1)ns |81,899,519 |

All four profiles specify2GHz, first edge0.25ns, final edge39999.75ns and end40000ns
exactly:80,000 raw receipts per scope,1,638,400,000 checks per native profile.
There is no post-budget drain. The complementary short/mid rows cover both
bases and quality/reset at maximum counts; dense and full-scene history rows
belong to the separate history-matrix acceptance. A failed or unrun row stays
unverified.

The inherited fixed feature settings enable episodes/phases on every point and
group, with Q30ns/60cycles, N3, span20ns/40cycles, K4, explicit hysteresis/fit/trend
coefficients, and all12 report rules per typed scope. Point protocols alternate
valid-only/valid-ready/credit by index modulo3; even indexes use dynamic64B and
odd indexes fixed64B. Supported backpressure/shortage hints are enabled at
4ns/8cycles. Credit capacity and known initial balance are16 with NEXT_CYCLE
returns every edge. Unsupported hints remain disabled. Full inputs, thresholds,
tool options and source/header hashes are retained in each run's manifest.

Unknown size keeps the known event, removes64B from the known subtotal and
marks only byte completeness. Exactly23 groups contain p0, including all eight
chain levels and its fifteen independent parents. Known reset removes two p0
events, restarts only its local statistics and leaves ancestor schedules/history
intact. Ancestors receive all original-time frames/controls and retain member
reset coverage until exact expiry. The independent final rows and every-result
checks distinguish cumulative raw traffic, local epoch totals and window counts.

Waves are off. The repaired runtime requires `rtl/bw_slot_settlement.c`, `+vpi`
and at least `-debug_access`. The runner passes the installed VCS SDK include
directory to the C compiler, snapshots every local RTL/C/header and harness
source before compilation, and fingerprints their contents. It uses
`-debug_access` without `+all`; removing debug access completely is unsupported
for this runtime. See [the scheduling contract](bw-mon-scheduling.md). SDK header
paths and SHA256 values are retained with the preparation evidence, without
redistributing vendor headers. GNUtime-v compiler/simulator peaks and sampled
process-family peaks are recorded separately; no memory or wall-time acceptance
cap is imposed.

## Current evidence

Current-source preparation was tested at commit `1508f8f6f03ae03768f107ce0cd472182c9b6654`,
after merging integration `cb0aef54f94efc8fd485bb97341cdcbe3f21e506`. All18 runtime
RTL/C/header SHA256 values match the repaired `8e81839` freeze. The fixed maximum
profiles, five literal contracts, shared input reference and generator are
unchanged from `2d5c685`. The five maximum and six legacy reference contracts pass.

The four separately named tracers ran32 actual points and24 groups for240ns,
including a depth-eight path and sixteen direct consumers of subgroup0. Each
checked26,880 raw receipts with zero differences under the required native build.

| Tracer | Window checks | Compiler peak KiB | Simulator peak KiB |
| --- | ---: | ---: | ---: |
| max-tracer-ns |1,344 |355,808 |127,156 |
| max-tracer-cycle |1,288 |355,808 |126,352 |
| max-tracer-unknown |1,344 |355,808 |127,304 |
| max-tracer-reset |1,287 |355,672 |127,460 |

These runs also checked controls, every direct-member ACK, complete release of
retained frames/controls, hints,56 typed scopes and final report ordering. Compiler
and runtime tool diagnostics were absent. Formal report WARNING results are
expected for the continuously active, truncated episodes. Portable inputs,
per-scope expected/actual rows, empty differences, logs, compile receipts, SDK
provenance and consumed source snapshots are in
[`tests/scale/evidence/maximum-preparation`](../tests/scale/evidence/maximum-preparation/README.md).
These small checks establish neither nominal memory nor nominal correctness.

All four native profiles remain **unrun for the repaired source**, awaiting the
current common-scale gate and resource admission. Their expected counts above
are unchanged. Each will instantiate20,480 public owners and therefore20,480
native reset observer contexts, plus one coalesced pending settlement callback.
The small measurements provide no justified maximum RSS extrapolation; actual
full runs must measure it.

The original source `2d5c685` had one license-service interruption and four later
partial runs stopped as `operator-superseded-source` when the scheduling defects
were confirmed. Their original manifests, logs and receipts are preserved in a
separate archive. They are neither current-source acceptance nor capacity
failures. The older no-debug compatibility probe applies only to its original
runtime and does not establish support for removing the new native dependency.
