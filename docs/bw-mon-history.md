# History and update matrix

The history profiles use actual public points, group owners, setup and report
owner, with the independent segment/leaf-set oracle from the common-scale harness.
Run `python3 tests/scale/history.py PROFILE --output-root PATH`. Small `tracer`
profiles use32 points/8 groups/240ns and never substitute for nominal rows.

The builder now includes repaired integrationcb0aef5, whose18 production files
match runtime8e818394. Its five history and six legacy literal contracts and all
six public history tracers pass. Every nominal history cell still awaits a fresh
actual run on this repaired source. Earlier completed runs, interrupted MAX
attempts and dated matrix files remain historical evidence for their original
source; none qualifies a repaired-source cell.

| Size | New regular-clock baseline cells | Reused version-qualified rows |
| --- | --- | --- |
| Common1024 points/256 groups |NS10/S1;cycle20/S2;NS40000/S1;cycle80000/S1 |completed29 NS100/S10 +cycle200/S20, unknown-size +point-reset variants |
| Max16384 points/4096 groups |same four new cells |30 short/mid rows only after actual completion; running/failed attempts remain unproved |

Every baseline keeps Ready0, first positive edge0.25ns,2GHz,80,000 frames per scope,
64B per point/edge and observation end40,000ns EXACT. No extra edge or positive
drain is added. NS long becomes full only at the40us publication. Cycle long
keeps W80000: only79999 complete cycles exist, so79999 dense publications remain
warmup/full0/valid0 even though their known rate is128×cardinality GB/s. Current
raw/live totals include the publication's right edge; its window excludes it.

All profiles retain the fixed mixed protocols/size policies and enabled supported
hint/credit/episode/phase/report combination documented in the scale guide.
These dense cells explicitly choose N3, K4, minimum span2×their stride, Q30ns or
60cycles, steady entry/exit ABS/REL0, RMS entry/exit ABS1e-6/REL0 and trendABS1/REL0.
Legacy profiles retain their original20ns/40cycle minimum spans. Every scene
records these engineering settings; they are not monitor defaults.

Waves are OFF. Repaired builds compile the native scheduling helper with `+vpi`,
minimum `-debug_access`, the SDK include path and every local header dependency,
using an immutable consumed source snapshot. Earlier matched32/8/240ns visibility
probes retain their original source qualification. Every nominal cell requires its own
actual checked run, source/options manifest, counts/reference/actual/diffs and
measured compiler/simulator RSS. No memory or wall-time acceptance cap is added.

Four additional nominal profiles are planned, NS/cycle at each size: W7/S3,
sparse p0 unknown size, group0 statistics reset,1GHz interval and legal clock stop,
with all original timestamps and explicit actual edge counts. They complement
rather than replace the regular2GHz baselines. Group-local reset must clear only
local statistics; collector/source/raw stream and ancestors continue, with no
physical point reset coverage or source-epoch change. An old ancestor episode's
unknown bytes stay incomplete after its windows recover. Their implementation
and actual measured status will be recorded with each profile's evidence.

All raw receipts and new window publications are checked online against original
inputs in O(clock segments+sparse exceptions), with exact integers/quality and
separate binary64 tolerance. Only per-scope final rows/counts and bounded final
records/progress are retained. A Python topology/reference result, smoke run,
resource injection, running job or failed infrastructure attempt is not a passed
matrix cell. Full common/max and all remaining cells are tracked independently.

## Clock/control input table

`history-{common,max}-{ns,cycle}-control-clock` uses W7/S3, N3/minimumspan6/K4,
Q30ns or60cycles and the same explicit coefficients/hints/credit/report rules as
the other profiles. Its original clock input is three arithmetic progressions:

| First edge | Period | Count | Last edge |
| --- | --- | ---: | --- |
|0.25ns |0.5ns |1000 |499.75ns |
|500.25ns |1ns |50 |549.25ns |
|600.25ns |0.5ns |78800 |39999.75ns |

There are79850 actual frames per scope; no edge or cycle is manufactured during
the51ns interval between549.25 and600.25ns. These are labelled variable-clock
variants; the separate baselines retain all80000 frames at2GHz for40us.
P0 dynamic size is unknown only on its real100.25ns transfer. Group0 statistics
reset is asserted300.1ns and released301.1ns. It creates no point-origin control,
physical reset coverage or source epoch change. Its two interrupted local
sampling opportunities still publish full group raw increments to ancestors.
The group's own stats epoch becomes1 while raw source epoch remains0; both
receipt and source sequence keep advancing through every original frame.

For a five-point leaf, the reset's first frame at300.25ns still carries320B/5events
upstream, while its local live total is0. At40us its post-release local total is
25359360B/396240events; the32-point parent retains163532736B over the scene,
including exactly the earlier missing64B known subtotal. Parent episode byte
quality stays incomplete after its windows recover. The new local group episode
is complete in bytes; the earlier reset-interrupted episode retains its unknown.

NS [593,600) is a full known-zero window. Cycle publication350 ends at actual
edge1051/600.25ns and starts at edge1044/543.25ns:448B per point over57ns gives
448/57GB/s, while B/cycle remains64. The pause exceeds Q30ns, but the last transfer's
real tail was unknown until resume; it must not create a completed episode during
that pause. Resumed transfer activity extends the old episode. The final tail is
again unknown at40us, so final truncation/representative validity remain explicit.

The public32/8/240ns clock/control tracers use an explicitly shortened input table
(20 half-ns edges,10 one-ns edges, resume30.25ns),450frames/scope, p0 sizeX40.25ns
and group reset70.1–71.1ns. They passed18000 raw checks each,3199NS/5959cycle windows,
41episode/41phase records and492 correct WARNING conclusions, zero differences.
They establish integration sensitivity only, not nominal40us acceptance.

## Historical recorded execution status

The first actual common NS40000/S1 baseline completed at40us exactly from frozen
source `ee69484e46d34ff83e89425dd822eb7017e2d0eb`:1024 points/256 groups,
102400000 raw receipts and51200000 publications checked,1280/1280 reference/actual
rows,zero differences. The final [0,40000)ns window is full/known/valid with5120000B
and80000events per point. Only that final publication is full, so N3 phase evidence
is unavailable:1280 episode finals,0 phase finals and15360 correct WARNINGs.
The actual tail remains unknown beyond the observation; no e2e endpoint is invented.

GNUtime-v simulation peak is221156KiB (215.97MiB); compiler peak350168KiB.
Elapsed1321.70s includes admitted max30 concurrency; it is not a speed requirement
or a comparison with other flags/workloads. Waveforms/debug visibility were off;
the original manifest records every option and source hash. Portable originals
and consumed source are in `tests/scale/history_evidence/`; its hash/row verifier
passes. These are actual full long-window results, independently of prior small
resource pilots. This record belongs to its original source and does not qualify
the repaired runtime; the first row did not complete the original matrix either.

`tests/scale/history_evidence/matrix.json` records the12 new cells and reused29/30
rows with a dated pre-repair status snapshot and exact independent expected
counts. Those source-qualified records remain historical. Fresh repaired-source
final manifests and verified bundles will establish current qualification. The common operator queue
admits at most four simultaneous common jobs, with isolated source/build/output
roots; this is host scheduling rather than a monitor capacity. Max jobs require
separate coordinator admission. Failed/interrupted attempts are preserved and
block further queued launches for review. No queued/running/unadmitted row counts
as completion, and the overall ticket remains open until all required actual
rows and version-qualified reused evidence are verified.
