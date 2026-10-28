# Integration, acceptance evidence and review

> 交付目录已精简：当前 PR 保留源码、最终摘要和截图。下面的历史证据链接指向固定提交；本地查看/复验请先看[证据与复现说明](bw-mon-evidence.md)。

The revised maximum-topology/history qualification follows current D16/T7/T8
and the [M1–M5 mapping](bw-mon-max-topology.md) / [H1–H7 mapping](bw-mon-history.md).
Its [serial quick/full runner](../tests/scale/revised_suite.py) enforces cold/hot
budgets and its [portable evidence](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/revised_evidence/final-campaign)
keeps maximum-scope, deep-history and shared consumer-lag evidence distinct.
The original canceled MAX matrix cannot satisfy this new completion gate.

The completed [revised campaign](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/revised_evidence/final-campaign/README.md)
uses frozen source `8c8f3d818979479b72fc9ed7f29b905ea9337396`: daily cold/cached
96.596s/25.528s and complete cold/cached906.636s/829.518s, all within budget.
Each complete suite checks21,670,663 new raw receipts and16,236,946 windows with
zero differences, plus15 directed cases and frozen COMMON replay. Both maximum
cases check every16,384-point/4,096-group scope and all65,536 direct identities.
The [current compatibility proof](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/review/compatibility/README.md) separately
passes all427 components and42 end-to-end scenes, including exact equality of672
public scope CSVs and canonical final packets. These are completed measurements;
PR review and issue closure are tracked separately.

The following earlier production18 proof belongs to the independently reviewed
final-steady fix `56127495`. The [427-case/168-top proof](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/final-component-proof/verification.json)
records component checkout `467b722`; the fresh42-scene public-input campaign
records its actual simulation checkout `cd07c77`. Their18 production files match
byte for byte at those recorded checkouts. Current wrappers split the monotonic
Ready wait from local identity readiness; topology fixtures additionally enable
an acceptance-only collector gate/resource observer. The earlier proof is not
relabeled byte-identical to these three changed source files. All42 original inputs/cfg and independent numeric references are
unchanged, and all33 original real Verdi images were freshly regenerated.
**Human review of the nine new analog views is confirmed:** MakeReadUnique
[confirmed that all meet requirements](https://github.com/MakeReadUnique/bw_mon/issues/33#issuecomment-6411618527)
on 2026-10-26. This covers the named views and intervals in
[the review issue](https://github.com/MakeReadUnique/bw_mon/issues/33), distinct
from automated checks of all42 scenes and scale qualification.

The fixed data bundle is [`59fc046a154945b6a6ae60220e663f7d5ee12bb6`](https://github.com/MakeReadUnique/bw_mon/tree/59fc046a154945b6a6ae60220e663f7d5ee12bb6/artifacts/acceptance),
with the exact fingerprint in the original checklist. The new analog views are
pinned to `23e50de1357afb43b6535ecb9874aa6586889528`. The
[older Chinese guide](bw-mon-wave-review-zh.md) remains historical context;
the GitHub review issue is the current review entry point. Later
documentation/status edits retain the original data identity.

Start at the [scene/gallery index](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/INDEX.md), which links
the original FSDBs, portable public views, fresh images, independent tables and
per-scene commands. The [earlier scene runtime/native freeze](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/runtime-source.json)
keeps actual scene checkout, production milestone and component checkout distinct.
Every scene retains version2 source/native receipts and an immutable project
archive. The actual VCS `.d` lists source+2SDK headers; the separate full survey
uses the actual implicit `-fPIC -O` options and includes50 native headers.
SDK/system header contents are not vendored. The427 proof retains its own original
49-header pre-run record and honest actual-flags50 post-run supplement.

The unchanged [historical424 proof](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/current-component-proof/verification.json),
[historical408 proof](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/component-proof/verification.json) and
[8e81839 freeze](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/historical-runtime-source-8e81839.json)
remain scoped to their original source. The [review history](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/review-history/README.md)
preserves earlier agent observations and pending human records. Fresh campaign
[input/cfg equality](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/input-equivalence.json),
[oracle equality](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/oracle-equivalence.json),
[capture provenance](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/capture-provenance.json),
[detached clean-checkout run](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/clean-checkout-repro.json) and
[actual relocated-view proof](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/portable-view-proof.json)
remain directly auditable after temporary builds are removed. The
[earlier handoff source inventory](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/current-source-manifest.json)
distinguishes actual consumed scene snapshots from later packaging/audit wrappers.
The [scale guide](bw-mon-scale.md) retains each scale campaign's exact source and
profile; these small wave scenes do not substitute for scale qualification.

## Three integration entries

[`tests/acceptance/scene.sv`](../tests/acceptance/scene.sv) is a complete runnable
example. Twelve actual `acceptance_port` DUT wrappers are observed by **one module-
type bind** to `bw_point_mon`. The wrapper decodes a bytes-minus-one field plus
an explicit zero-byte flag/knownness; the reusable monitor sees accounted bytes.
P%3 selects valid-only/valid-ready/credit; P%2 selects dynamic/fixed64B. The unused
valid pin is0 on credit links, while flitv sends independently. The protocols
variant also proves validX with ready0 is known idle, and flitv1/lcrdv0 still counts.

One `bw_group_mon` per group observes the common real clock and its local statistics
reset. `die0_dmc={p0..p3}`, `die1_dmc={p4..p7}`, `all_dmc={die0_dmc,die1_dmc}` and
`mixed={die0_dmc,p8,p9}`; p10/p11 remain independent. Direct/recursive cardinalities
are4/4,4/4,2/8,3/6. One parameterless setup discovers the12 points and4 real group
instances, then automatically seals their t=0 member rules. Traffic starts on an
actual edge strictly after the published common measurement start T. No manual
publication/read/ACK or finish call is needed.

Default Point ID is the bound public monitor hierarchy. The example overrides
IDs to p0...p11. E5 explicitly registers `tb.top.master0.bw` and `memory_all`,
matching the spec cfg example without wildcards or inherited targets. Identity
is typed: point/group equal-text IDs remain distinct. Actual fixed public paths
are `/<top>/scene/ports[p]/dut/mon` and `/<top>/scene/{die0,die1,all_dmc,mixed}`.
Local reset changes only local statistics/epoch; source records/receipts continue.

## Complete configuration references

The [API tables](bw-mon-api.md) specify required/default/illegal behavior for all
protocol, fixed/dynamic bytes, credit, hint, identity/member, window,
episode and fit parameters. [Numeric/storage contracts](bw-mon-numeric-storage.md)
are authoritative for raw knownness, ranges, exact retention, representation
failures and resource accounting. Key facts for integration:

| Configuration | Object / unit / defaults and constraints |
| --- | --- |
| Sampling/time | All production scopes1fs/1fs; timestamps unsigned64 fs. Edges must be strictly later than published T; maximum target2GHz. The inclusive T+40us budget is never renewed by local reset. No extra drain beyond budget. |
| Setup | One parameterless instance discovers up to16384 points and4096 groups, including ungrouped points. It seals after all finite t=0 scheduling, prepares all scopes and reports in the first positive slot, and publishes ready once. No manual counts or public timeouts. |
| IDs/members | Point default `__BW_AUTO__`, explicit nonempty unique overrides. Each real group instance declares its Group ID. Direct counts are derived after typed deduplication. Exact/dot-segment Point prefix or exact Group membership, no cycles/recursive overlap. Same W/S/basis and a common sampling clock. Depth8, edges65536, parents16. |
| Window | Raw logic2 basis defaults BW_NS; raw logic64 W/S required0<S<=W. W<=40000ns or80000cycles. Physical coverage/GB/s remain actual, including stop/frequency gaps. |
| Accounting | Protocol default valid-only, also valid-ready and credit. Dynamic policy rawlogic2 known0/1 defaults0; fixed bytes default0, known0..2^32-1. Dynamic size/knownness are per transfer; zero bytes remains an event. |
| Credit | Enabled only by explicit known0/1 policy (default0); known capacity required, zero legal; initial knowledge default0, known seed must be within capacity. Return defaults NEXT_CYCLE, optional SAME_CYCLE. Diagnostic anomalies lose trust without clamping or changing known bytes. |
| Hints | Each independent known0/1 enable defaults0. Supported/enabled hints require explicit BW_NS/BW_CYCLE basis and positive64-bit threshold; defaultsX otherwise unused. NS follows live conditions during clock stop; cycle counts complete local cycles. |
| Episode | Explicit known0/1 enable default0; enabled Q required known positive64 in window basis. No universal Q. Actual next edge supplies tail; confirmation silence is excluded from e2e duration. |
| Phase | Explicit known0/1 enable default0, requires episodes. N>=3, positive minimum span and K; each absolute/relative fit coefficient must be explicit finite/nonnegative (sentinel defaults-1). Exit>=entry and trend strictly separates steady. Fit REL0.05 means5%, while cfg REL5 means5%. Storage/index limits are representational, not user queue settings. |
| Performance | [Complete48-key table](bw-mon-expectations.md),12 metric families, exact typed full ID; lower/upper/range plus additive absolute+percent tolerance, defaults absent bounds/zero tolerances. CV absolute tolerance is percentage points. No automatic stage enable/target/scale/inheritance. |

Known disabled policies may leave unused seeds/thresholds unknown; unknown policies
cannot silently disable validation. Raw control/size/reset X/Z is observation quality,
not malformed numeric metadata. Checked arithmetic rejects unknown/overflow before
narrowing. No user history slots/depth/RAM cap or product wall-time overhead
benchmark exists. Revised acceptance-tool budgets are separate: daily120s hot /
300s cold, maximum case600s, history case300s, and complete serial suite1800s.

Every scene records exact W/S/Q/N/span/K/fit/hint values, first clock phase, every
raw control/amount row, reset intervals, actual end, source/header/oracle/cfg hashes
and commands. Most scenes use2GHz, W10/S1ns or20/S2cycles, Q12ns/24cycles,
N3/span2ns or4cycles/K2 and explicit absolute0.01 fit tolerances/trend5, REL0.
E3/E4 exact-vector contexts declare their different clock/analysis configuration;
they do not overwrite the T4 baseline or pretend an absent next edge occurred.

## Public results and log/error location

[Public field manifest](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/public-fields.json) and each view's
`signals-*.json` provide actual names and fixed paths. Integers/ticks, real values,
enums and independent quality flags live directly at point AND group scope.
Window `result_seq`, raw/control/acceptance sequences, stats/source epochs and
phase/episode final sequences have distinct meanings. Latest immutable
`episode_result_*`/`phase_result_*` and selected original phase identity remain
visible while live fields already describe another episode. Inspect validity and
reason before interpreting any backing real0. Warmup, unknown bytes, diagnostic
trust, unknown tail, absent stage and incomplete process remain separate conditions.

| Stream | Meaning and location context |
| --- | --- |
| BW_READY | Frozen participant counts and common measurement start after valid configuration. |
| BW_EPISODE | Typed scope/epoch/episode/final seq, first/last/actual tail/confirmation, original bytes/events/duration, independent quality and e2e. |
| BW_PHASE / BW_PHASE_METRICS | Original phase identity, candidate boundary versus confirmation, final interval/raw snapshots/duration/raw BW and quality. Earlier complete fragments survive later interruption. |
| BW_VARIATION / BW_LAST_STEADY | Publication selection/W/S/count/times/span/mean/min/max/population sigma/CV, validity/reasons/exclusions; final representative retains original phase identity. |
| BW_CHECK | Only configured metric: typed full identity, epoch/episode/phase/final seq, interval/unit/actual or UNAVAILABLE, bounds/tolerances/expanded range, cfg file/lines, conclusion/reason. |
| BW_CFG WARNING | Invalid file/line/key/typed ID and isolation reason; affected metric disabled, other usable rules continue. |
| BW_SUMMARY | Once after all registered scope finalizers: separate PASS/FAIL/WARNING counts,16/16 participant barrier here. FAIL outranks WARNING and later PASS never clears FAIL. |
| BW_HINT_HIT / BW_HINT_END | Local protocol condition, start/trigger/end/duration/reason and independent counts. They never add performance FAIL/WARNING. |
| BW_CORE_ERROR | Fatal code/scope/time plus expected/received edge/sequence, identity/conflict paths or arithmetic/resource use. Never downgraded to performance WARNING. |

The [concrete error index](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/error-catalog.json) links literal/
durable codes to source locations and expected-fatal cases. Registry/ownership/
context/DAG errors locate objects and both overlapping paths; record/time/sequence/
ACK errors locate expected versus received source data; numeric/storage errors
locate operands/resource/current/requested use. Full descriptions and allocator
limits are in numeric/storage docs. Deferred timeout actions are read-only;
finalization suppresses formal outputs after terminal/pending core failure.
This VCS may return status0 for `$fatal`, so the test runner checks Fatal text,
precise error code and absence of continuation, not shell status alone.

## Commands, artifacts and review

```sh
make test                         # current component manifest (427 cases)
make acceptance                   #42 fresh public scenes, FSDB and independent checks
python3 tests/acceptance/run.py --scene size_unknown --basis cycle
python3 tests/acceptance/publish.py --pack
python3 tests/acceptance/audit.py  # recorded-source/trace audit; no simulation
python3 tests/acceptance/views.py --capture --display "$DISPLAY"
cd artifacts/acceptance/steady_ns
./open.sh overview                 # portable FSDB + fixed public signal view
```

VCS/Verdi W-2024.09-SP1_Full64, Python3.6.8 and actual compile/run/capture options
are preserved. Compile package, report package, other RTL, the private
`rtl/bw_slot_settlement.c` helper, then scene; use
-full64/-sverilog/+vpi/-debug_access+all/-kdb, +incdir+rtl, -assert svaext and
`-CFLAGS -I<VCS>/include` for the installed `svdpi.h`/`vpi_user.h`. Plain
non-wave builds require `-debug_access` or `-debug_access+all` too. The helper
settles kernel scheduling; measurement and analysis remain in SV, with the same
three public integration entries. See [scheduling/build details](bw-mon-scheduling.md). The FSDB
PLI was automatically linked by the recorded local installation. Other installations
must provide their normal VCS/Verdi FSDB setup. The simulator uses -no_save. Dump
scope depth1 includes actual DUT pins/public monitors; no private Core layout is
required by views. X11 is required only for capture/viewing; headless capture can
use Xvfb with a window manager. Exact local paths are provenance, not required
checkout locations. Scripts resolve their source/output relative to this checkout.

The current runner writes version2 `runtime_evidence`, the VCS-generated
`native-dependencies.d`, a full transitive native `.d`, and `source.tar.gz` for
its actual project snapshot. The cache fingerprint covers project source,
transitive native header hashes, exact compile options, tool identities and the
compile environment. `--cflags` adds native C options and is part of that
fingerprint. A changed header or option selects a new immutable build directory;
missing executables or actual native dependency receipts force compilation.
SDK/system headers remain filenames, hashes and compiler identities; their
installed contents are not copied into the project archive.

`publish.py --pack` packages actual raw inputs/CSV/logs. `audit.py` checks the
recorded scene source archive and independent numeric results after `.build` is
removed; it does not require today's source or SDK to equal a historical build.
`audit.py --current-source` additionally requires every scene's production hashes
to match this checkout, and rejects mixed or stale production snapshots. Each
scene retains its actual checkout revision and production hashes. The global
`production_sources` list identifies every consumed runtime; a mixed bundle does
not claim one current production base or borrow the old component qualification.

The [historical project archive](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/historical-source-8e81839.tar.gz)
preserves the23 actual8e81839 project files consumed by the original42 scenes,
including the original runner/reference scripts. Its bytes were checked against
all42 existing manifests. The original frozen assets remain unchanged. Editing
the current runner therefore does not relabel their provenance or make their
recorded-source audits depend on today's harness. The historical424-case
verifier continues to check its exact original source and counts.

A rerun changes its scene's data and provenance. Prepare new public views and
capture fresh images for any changed scenes that previously had images before
publishing the bundle. The publisher rejects stale images. Regenerated assets
return human review to PENDING; neither a rerun nor publication supplies actual
human attestation.

Full original input, CSV and compile/runtime traces are retrievable in each scene's
trace archive; FSDB, views, PNGs, references, tables and manifests remain directly
accessible. Captures are fresh real Verdi1500x850 client images; digital numeric
real rows avoid interpolation, and integer bytes/bounds independently establish
values. No simulation data or raster was altered. Scientific formatting exposes
exact distinctions such as152 versus151.99. Saved views reference nearby FSDBs.

The [original T6 checklist](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/HUMAN-REVIEW.md) names actual
objects, intervals and expected observations across both bases and independent
variants and retains its generation-time PENDING text. The
[human ledger](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/artifacts/acceptance/review.json) records the user-authored
confirmation of the nine analog views in [the current review issue](https://github.com/MakeReadUnique/bw_mon/issues/33),
including confirmation time, exact objects/intervals and hashes. Agent image
inspection remains separate. The exact viewing time was not separately supplied;
the recorded time is the GitHub confirmation time. This does not claim human
inspection of every original scene or older image. One attestation cannot claim
review of future assets. HTML illustration/probe screenshots and small resource
pilots do not stand in for real monitor/human/nominal-scale acceptance.

After a genuine named ledger entry is recorded, `python3 tests/acceptance/publish.py`
revalidates the existing assets and renders the current global human status in
`verification.json` and INDEX. It retains the entry only for the same asset
fingerprint and matching `artifact_sha256` bindings for any separately named
review assets; changed assets return the current status to PENDING. This command
retains the archived previous record on later pending republication without
adding duplicate archives, and does not create an attestation. Scene rows describe
automated results, and `human_review_at_generation` records their original generation-time state; neither
implies separate human approval of every scene. Original comparison/capture
manifests and expected/actual tables retain their historical PENDING text and
bytes. Do not use `--pack` for a review-status refresh.

`python3 artifacts/review-analog/verify.py` permits the four publisher summaries
(`review.json`, `verification.json`, INDEX and SHA256SUMS) to reflect current
status while checking their complete current inventory. It still checks all922
other historical files against the capture-generation inventory, all nine
analog capture receipts, and the named human review's artifact hashes.

`python3 tests/acceptance/test_reproduce.py` runs real VCS scene generation,
publication/packing and portable audit in a disposable committed checkout. It
also checks native transitive-header and compiler-option cache invalidation.
`python3 tests/acceptance/test_publish.py` tests the publishing CLI with real frozen
assets copied into disposable directories, using explicitly SYNTHETIC records
only. It checks matching-fingerprint retention, changed-asset invalidation and
byte preservation without touching the real ledger, simulation or capture.

## Contract to evidence

| Clauses | Component anchors (current427; historical424/408 retained) | Public scene evidence |
| --- | --- | --- |
| D1–D3/T1 | ns_bind, startup_*, group_matching, hierarchy_* | All42 use12 bound wrappers +4 groups/setup; exact IDs/free points/multi-parent mixed DAG. |
| D4–D5/T3 | protocol_recording, sample_view, credit_* | protocols ns/cycle: validX&ready0 known idle; credit valid0/flitv1/R0 definite send; fixed/dynamic amounts. |
| D6–D7/T4/T5-E1 | hierarchy_t4_ns_*, hierarchy_t4_cycle_*, retention/depth cases | Steady at2GHz64B:128/512/1024/768GB/s and64/256/512/384B/cycle; exact104ns increments under point/child reset/unknown size, plus upper reset. |
| D8–D9/T5-E2 | subns_vectors, cycle_window, reset_same_time_* | e2 both bases, isolated endpoints, start_stop, unknown/reset, clock_stop/frequency. E2 relative0 maps legal physical1ns after Ready. |
| D10/T5-E3 | episode_boundary/cycle/gaps/controls/final | e3_boundary: [80,102),confirm132, old-before-new132ns runtime markers in point+affected groups; zero/no_episode/truncated. |
| D11/T5-E3 | phase_delayed/hysteresis/actual_clock, metrics_delayed | e3_delayed: candidate120/confirm150, clipped[120,136), raw0 versus6.4 windows; varying/repeated stages. Fraction OLS uses actual publication times, K and independent qualification. |
| D12 | metrics_repeated/zero/quality/independent/first_boundary/stopped_history | Independent exact raw interval counts and population statistics for every delivered phase/episode; last steady PASS while whole CV FAIL, no earlier plateau substitution. |
| D13/T5-E4–E5 | report_* all48 keys/strict parsing/replays/barrier | e4 actual128/151.99FAIL and152PASS at effective152; e5 exact point/group IDs and only configured family sets; all conclusions/counters independently checked. |
| D14 | hint_* / credit_* | protocols + hints: NS hit during stopped cycle clock, unknown gap split, independent byte/metric counts. |
| D15/D17/T6/T8 | public point/group result aliases | Original FSDBs/views/images and explicit human ledger retain the confirmed named nine-view review. New compatibility FSDBs have automated equality proof and no new human attestation. |
| D16/T7 | numeric_*, history_trace_*, variation_pending_retention, transport_growth, storage_failure_* | Completed M1–M5/H1–H7 serial cold/cached suites: actual maximum topology, deep/merged history, shared delayed consumers, exact numeric checks and measured resource/budget evidence. |

The scene index states source revisions, configurations, independent counts/results
and review status. Earlier per-ticket proof counts in API history stay historical;
this handoff links retained proof and source-specific scene evidence without conflating
automation, human review or scale targets.
