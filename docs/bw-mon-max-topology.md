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

Waves are off. This runner omits `-debug_access+all`; a separately recorded
four-profile matched small public-module probe established identical numeric and
formal results with that sole option change. No speed claim follows from the
probe. Original common-scale measurements retain their original compile options
and source version. GNUtime-v compiler/simulator peaks and sampled process-family
peaks are recorded separately; no memory or wall-time acceptance cap is imposed.

## Current evidence

The four separately named tracers ran32 actual points and24 groups for240ns,
including a depth-eight path and sixteen direct consumers of subgroup0. Each
checked26,880 raw receipts; the four window totals were1344/1288/1344/1287, all
with zero differences. They also verified controls, per-direct-consumer release,
hints and final report ordering. These small checks validate the reused harness
and provide no nominal-scale pass claim. Native measurements are pending.
