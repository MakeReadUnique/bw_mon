# Scale correctness and resource runs

The reusable harness in `tests/scale/` drives actual `bw_point_mon`,
`bw_group_mon` and `bw_mon_setup` instances through their public raw interfaces.
It checks each raw receipt and each newly published window online, then compares
bounded final scope rows against an independent Python reference. It does not
use a monitor output, private history, queue slot count or HTML trace as a golden
model. Specification D16–D17/T2/T7–T8 and [common-scale acceptance](https://github.com/MakeReadUnique/bw_mon/issues/29)
define the required profile. Small runs are explicitly named smoke runs.

Run from the repository root with Python3.6+ and VCS available:

```sh
python3 tests/scale/test_reference.py
python3 tests/scale/tracer.py
python3 tests/scale/run.py smoke-ns smoke-cycle smoke-unknown smoke-reset
python3 tests/scale/run.py common-ns common-cycle common-ns-unknown common-ns-reset
```

The last command runs four separate, full-duration profiles sequentially. The
first is the prescribed baseline; variants do not replace it. No monitor memory
capacity, fixed RSS ceiling, wall-time limit or monitor-free speed benchmark is
introduced. Coordinate large jobs to avoid exhausting the shared host. Use
`--output-root PATH` to preserve results outside `.build/scale`; every invocation
creates a durable attempt directory rather than overwriting earlier failures.

The small `tb_scale_tracer.sv` is a three-point → child → parent vertical slice.
It checks120 windows and2400 raw receipts in240ns, including all three protocols.
Its `+INJECT_CHECKER_ERROR` changes the reference by one byte and must produce
`TRACER_WINDOW_MISMATCH` at10ns; that failing sensitivity run is not an acceptance
profile or a production fault-injection API. VCS can return exit0 for `$fatal`,
so the runner checks terminal diagnostics and durable completion evidence.

## Historical common-scale measurements

These completed measurements belong to their original source074c771. Scheduling
repairs in integrationcb0aef5 require fresh nominal qualification; the original
numbers and archives remain historical observations. On the repaired18-file
runtime8e818394, the six literal contracts, three-point public tracer with its
deliberate one-byte sensitivity failure, and four32point/8group smoke profiles
pass. Those small checks do not qualify the four new full common profiles. Their
fresh immutable-source runs and resource records are tracked separately until
all actual40us runs finish and their references, hashes and reports are checked.

All four profiles below completed at **40us exactly**, using frozen harness/source
`074c77103bc8c135106facad00dbc21995f2d92f` (production integration8de785c).
Each instantiated1024 actual public points and256 group owners. Every profile
produced1280 expected/actual final scope rows with **zero differences** and
102,400,000 checked raw receipts. Both baseline streams additionally passed the
independent steady-candidate/confirmation audit:120/150ns forNS and
120.25/150.25ns forcycle, with unavailable final representative selection.

| Full profile | Window checks | Episode / phase final records | Simulation peakRSS KiB (MiB) | Compiler peakRSS KiB |
| --- | ---: | ---: | ---: | ---: |
|Prescribed NS100/10 baseline |5,120,000 |1280 /1280 |307,452 (300.25) |355,736 |
|Cycle200/20 |5,118,720 |1280 /1280 |306,148 (298.97) |350,664 |
|NS100/10, p0 unknown size |5,120,000 |1280 /1280 |306,632 (299.45) |352,408 |
|NS100/10, p0 known reset |5,119,999 |1281 /1280 |306,384 (299.20) |350,664 |

The four runs checked409,600,000 raw receipts and20,478,719 published windows in
total. Reset's one extra episode is p0's independent RESET_INTERRUPTED episode;
its own lifetime window count is3999 while ancestors retain4000. All final
summaries had1280/1280 scopes done. Baseline/cycle/unknown each concluded15360
WARNINGs; reset15372. Those are correct unavailable-metric conclusions for the
continuous-flow truncation, not test failures or forced performancePASS.

Source hashes21files and generated hashes3files match the consumed snapshots;
all four compiles were clean/successful with no infrastructure retry. Simulator
exit codes are0, full expected/actual/diff and hash checks passed, and all streams
settled before their single final report summary. The numerical tests never use
the performance conclusion as their pass predicate.

The host had31,857MiB RAM and8 logicalCPUs. After observing stable footprints,
the acceptance coordinator allowed up to four isolated common jobs concurrently;
compiler/simulator peaks remain separate per-command GNUtime-v measurements.
Concurrent wall durations and1s process-family samples are retained with full
context, with no speed or fixed-memory acceptance limit. Maximum-scale and
short/middle/long/dense history-matrix measurements remain separate work.

[Portable recorded evidence](../tests/scale/evidence/README.md) contains the
original manifests/config/input/generatedSV, per-scope reference/actual CSVs,
empty differences, bounded final-stream logs, resource records and consumed
source snapshot, with compressed and original SHA256s. Verify its repository
copies without any /tmp dependency:

```sh
python3 tests/scale/evidence/verify.py
```

## Fixed inputs and complete feature configuration

| Setting | Common baseline | Cycle variant | Quality/reset variants |
| --- | --- | --- | --- |
| Public instances |1024 points +256 groups |same |same |
| Topology |224 leaf groups +32 parents, two levels, no reuse |same |same |
| Clock |2GHz, first edge0.25ns, last39999.75ns |same |same |
| Observation |Ready/start0; end40000ns exactly |same |same |
| W/S |100/10ns |200/20 actual cycles |100/10ns |
| Activity |64B/event on every edge/point |same |one explicit p0 intervention |
| Protocol |point index mod3: valid-only, valid-ready, credit |same |same |
| Size policy |even point indexes dynamic; odd fixed64B |same |same |
| Inputs |valid=ready=flitv=lcrdv=1; dynamic size_known=1 |same |see below |
| Credit |enabled on credit points; capacity16, initial16/known, NEXT_CYCLE return |same |p0 is valid-only |
| Backpressure hint |enabled on valid-ready points, NS/4ns |cycle/8cycles |same as baseline |
| Shortage hint |enabled on credit points, NS/4ns |cycle/8cycles |same as baseline |
| Episode |enabled on every point/group; Q30ns |Q60cycles |same as baseline |
| Phase |enabled everywhere; N3, minimum span20ns, K4 |span40cycles |same as baseline |
| Hysteresis |steady entry/exit ABS0/REL0; RMS entry/exit ABS1e-6GB/s/REL0; trend ABS1GB/s/REL0 |same |same |
| Report |explicit scene rules for all12 supported metrics on every typed scope |same |same |
| Setup deadlines |startup100ns; missing-record1ns from original expected edge |same |same |
| Time/dump |1fs timeunit/precision, no waves/FSDB |same |same |

These engineering settings are scene inputs, not new product defaults. Supported
hints are enabled; unsupported hint classes remain explicitly disabled. Continuous
sends and one return per edge keep every credit ledger trusted at balance16, with
no shortage or backpressure hits. The checker verifies support/enable/credit/hit
state and control counts at the final scope barrier. No credit anomaly is used to
create an otherwise illegal traffic stream.

The clock input has a1fs high pulse at each listed positive edge; only actual
positive-edge intervals define the2GHz sampling period. The setup deadline values
above are the fixed public-module defaults in the recorded source revision.

Each parent contains seven disjoint leaf groups: four five-point leaves and
three four-point leaves, hence32 recursive points. Across the graph this gives
128 five-point leaves,96 four-point leaves and1248 direct member edges. Each
source has one direct parent; every point is grouped. The reference independently
builds leaf sets and checks overlap, depth, edges, fanout and cardinalities.
Groups are `scale.gN`, owned at `tb_bw_scale.groups[N].slot.mon`. Points use the
ordinary default full-path identity `tb_bw_scale.points[N].slot.mon`. An ordinary
index input in the test wrapper avoids a different point-module parameterization
for each identity. Only protocol/size policy selects point parameter variants.

`common-ns-unknown` changes p0's dynamic size to X only around its actual edge at
100.25ns. That event remains known; its64B are absent from the known subtotal,
byte completeness isfalse, event completeness remains true. Only scopes whose
independent leaf set contains p0 are affected. Unknown evidence expires normally
from their windows; episode quality remains independently sticky.

`common-ns-reset` asserts p0 reset at100.1ns and releases at101.1ns, without
manufacturing clock edges. Edges100.25/100.75 carry known reset records and no
activity. Point statistics restart at release, retain lifetime result/receipt
identities and rewarm. Ancestor statistics retain their original origin/history,
lose only two p0 events and expose known member reset coverage; group targets
remain their original cardinality. Source sequence remains80000; p0 source/stats
epoch becomes1 and its original reset control sequence reaches3. Groups still
forward/accept all original frames and origin controls. This differs from a
subgroup statistics reset, which does not represent a physical point reset.

## Independent calculations and every-result checks

`scenario.py` uses original arithmetic clock segments and independent recursive
leaf sets. Number of edges strictly before t is the sum of clipped arithmetic
progression ranks; `[a,b)` counts subtract two ranks. Sparse interventions replace
only an affected leaf's contribution. Python arbitrary integers/Fraction supply
final exact reference values. The generated SV checker evaluates those same
stimulus formulas online, independently of the DUT's retained runs, rolling
counters or classifier. Literal tests check known NS/cycle boundaries, unknown
known-part sums, point-local reset origins and both common/maximum graph caps.
The maximum graph function is reusable preparation, not a maximum-scale run.

Every public `accepted_record_seq` checks consecutive receipt/raw/edge sequence,
original timestamp, source/stats epoch, known byte/event increments, independent
quality/reset flags and live totals. Every public `result_seq` checks consecutive
publication identity, both endpoint units, exact coverage, known bytes/events,
warmup/full, quality, denominator/window validity, reset coverage and calculated
GB/s/B/cycle. Integer/flag comparison is exact, including X rejection. Real
numerical error allowance is `1e-9 + 1e-12*abs(expected)` in the reported unit;
this accommodates binary64 rounding of independent rational calculations. It
never widens the separate performance cfg targets.

Right-end events are excluded from windows and included in the separate settled
raw receipt/live total. The baseline has80000 actual edges/records per scope,
not80001. Each M-leaf scope has80000M events and5120000M bytes. NS publishes4000
windows, final `[39900,40000)`ns with200M events/12800M bytes/128M GB/s. Cycle
origin is actual edge1; publication r ends at edge`1+20r`, so there are3999
publications and the last window is`[39890.25,39990.25)`ns. Its200 actual cycles
give128M GB/s and64M B/cycle. The simulation continues beyond that last window
until the original80000 raw receipts and40us endpoint are also checked.

The p0-reset point has3999 NS publications, final`[39891.1,39991.1)`ns and
79798 local events/5107072B after release. Its ancestors have79998 p0 events over
the full scene. For the five-point leaf at110ns the reset variant has63872B/
998events, known complete/reset-covered; the unknown-size variant has63936B/
1000events, byte-incomplete/event-complete. No normalization to active membership
is performed.

Every scope checks its final controlled transport queries: no unacknowledged
frames/controls remain; each direct group-member ACK reaches80000; declared and
recursive group counts match the independent topology; all expected origin
controls were accepted. At40us, a durable completion count waits for every scope's
raw and window checks in the same simulation slot. A read-only deferred assertion
rejects incomplete settlement. There is no positive drain interval beyond the
immutable40us limit. Bounded1us progress records permit observing long runs.

## Final results and performance conclusions

All prescribed traffic continues through39999.75ns. The next tail-cycle edge
would be40000.25ns, outside the observation. Final episode status is TRUNCATED;
tail/e2e and formal last-steady selection are unavailable. The harness verifies
those independent result identities, raw counts/quality and validity, rather
than dividing by observation end or inventing a tail. In the reset case, p0 also
has an earlier RESET_INTERRUPTED episode; final sequence/episode IDs remain
monotonic. Phase result sequences are checked separately.

Generated cfg supplies all12 metrics, using explicit per-scope bounds at the
original128×cardinality GB/s where applicable,0 sigma/CV, and40000ns time maxima.
These values are fixed scene targets; see [the complete key table](bw-mon-expectations.md).
Unavailable truncation evidence produces WARNING with `actual=UNAVAILABLE`.
Performance PASS is not required for a correct run. Every configured metric must
settle once per applicable final episode (ramp/fall fragments may settle
independently). The runner cross-checks conclusions against the final summary,
which must appear once after all final streams with all1280 scopes done. It does
not replace the real report owner with a test subscriber.

## Durable evidence and memory interpretation

Each attempt retains original input/topology/leaf sets, all analysis/hint/credit/
report options, source commit/tree/dirty status, every source/header/helper/
generated fixture/cfg hash, tool versions, exact argv/cwd, start/completion/exit
status, and GNU time-v compiler and simulation peak RSS separately.1s process-
family RSS samples supplement GNU time's per-process maximum when a compiler
has children. Sampling imposes no abort threshold. Failed/interrupted attempts
remain distinguishable from verified completion; compile failures are retained
in separate compile-attempt directories. Source snapshots are private to the
build fingerprint, so later edits cannot change an active simulator's source.

`expected.csv`/`actual.csv` contain one final row per scope, with checked raw and
window counts; `diffs.json` identifies any difference. `verification.json`
summarizes all online checks and final streams/report totals. `manifest.json`
records resource results and SHA256s. `simulation.log` contains bounded progress
and final production records, never one row per raw event or window. A fatal
checker reports the first mismatch with scope, sequence, boundaries, values and
quality; missing final rows then prevent success. Smoke evidence cannot be
relabeled as a full run.

Main retained state includes exact equal-event/clock runs, rolling totals,
quality-control intervals, N fit samples, clippable pending publication/fragment
history, bounded selected/settled metric summaries, source backlogs until all
direct consumers ACK, origin/control state, registry leaf masks/member edges,
credit/hint and report state, plus simulator/checker/container overhead. Communication
backlog is measured by delivery/consumption, not assumed to equal80000 cycles;
ancestors do not each retain a copy of the complete leaf event stream. Uniform
run compression helps this declared activity, while irregular input can require
more storage. There is no user history capacity knob or universal heap guarantee.
See [numeric/storage semantics](bw-mon-numeric-storage.md) for the implementation
contract and version-qualified earlier pilot evidence. A64-point pilot or a
one-point duration delta is not a linear prediction of common/max scale memory.

Source-level logical estimates for this1280-scope uniform scene help interpret
RSS; they are not simulator heap sizes or required allocations:

| Retained category | Count/model | Logical payload before containers/alignment |
| --- | --- | --- |
| Equal event runs |one compatible run per scope; sparse variants briefly split affected runs |579bits/run, about90.47KiB for1280 runs |
| Physical clock runs |cycle mode, one constant-period run per scope |320bits/run,50KiB for1280 runs |
| Fit evidence |N3 ×1280 |3840samples; two64bit positions +one real each,90KiB |
| Registry recursive masks |current fixed16384bit representation ×256groups |512KiB |
| Direct ACK values |two64bit cursors ×1248edges |19.5KiB, excluding keys/maps/member lists |
| Report rules |12 ×1280 |15360rules; roughly0.947MiB logical fields, excluding padding/containers |
| Clipping/quality/result state |per scope, plus sparse original-time controls |additional summaries, pending runs/fragments, origin maps and immutable result payloads |

These run counts are an inference from the declared equal increments/qualities
and source representation, not a private slot-count acceptance assertion. Event
expiry occurs at publication: W100/S10 can temporarily represent220 logical
positions before the next prune. Equal-run storage retains their exact positions
without allocating220 normalized records. Cycle boundaries expire by actual edge
and retain the needed left boundary/current context. Origin/control maps,
source/current frames, pending actions, strings and simulator/debug/checker state
add overhead; summing only packed payloads cannot predict total RSS. The final
ALL-ACK queries establish zero outstanding transport at settlement, rather than
assuming all80000 records were buffered. No RAM bound follows from these estimates.
