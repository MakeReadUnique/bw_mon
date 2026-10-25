# History and update matrix

The history profiles use actual public points, group owners, setup and report
owner, with the independent segment/leaf-set oracle from the common-scale harness.
Run `python3 tests/scale/history.py PROFILE --output-root PATH`. Small `tracer`
profiles use32 points/8 groups/240ns and never substitute for nominal rows.

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

Waves are OFF. These new builds omit unnecessary `-debug_access+all`; the separate
matched32/8/240ns four-profile probe verified public rows/formal records with and
without that visibility option. This is small compatibility evidence, not a speed
or nominal-scale equivalence claim. Every nominal cell still requires its own
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
