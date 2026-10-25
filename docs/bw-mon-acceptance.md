# Integration, acceptance evidence and review

The monitor and component contracts are implemented. The current durable component
proof contains424/424 VCS cases on frozen runtime `8e818394`; the public12-point
campaign was rerun against the same18 production files with42 unchanged original
input/configuration scenes and33 fresh real Verdi captures. These are
automated results. **Human T6 review is pending** until an actual person reviews
and records the completed bundle. Agent inspection never supplies that attestation.
The [scale guide](bw-mon-scale.md) retains each campaign's exact source/profile
manifest; these small wave scenes do not substitute for scale revalidation.

Start at the [scene/gallery index](../artifacts/acceptance/INDEX.md), not the
architecture HTML's illustrative curves. It links original FSDBs, public signal
views, fresh Verdi images, input/configuration, expected/actual/difference tables
and provenance. The [current424 proof](../artifacts/acceptance/current-component-proof/verification.json)
and its [portable archives/verifier](../artifacts/acceptance/current-component-proof/README.md)
cover167 tops and3 minimum-option runs. The unchanged [historical408 proof](../artifacts/acceptance/component-proof/verification.json)
and [archive](../artifacts/acceptance/component-proof/final-408-proof.tar.gz) retain
their original numeric/storage27 source scope. The [runtime freeze](../artifacts/acceptance/runtime-source.json)
records18 RTL/C/local-header hashes and49 transitive native-header hashes; each
scene's commands also preserve its actual consumed snapshot and native `.d`.
The [current source/test hashes](../artifacts/acceptance/current-source-manifest.json),
[original-input/config equality](../artifacts/acceptance/input-equivalence.json),
[fresh-capture provenance](../artifacts/acceptance/capture-provenance.json) and
[actual relocated-view proof](../artifacts/acceptance/portable-view-proof.json)
remain directly accessible after temporary build directories are removed.

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
are4/4,4/4,2/8,3/6. One setup declares12 points AND4 groups. Definitions/member rules
then `finish_configuration()` seal the DAG; traffic starts on an actual edge
strictly after Ready. No manual publication/read/ACK/time advancement is needed.

Default Point ID is the bound public monitor hierarchy. The example overrides
IDs to p0...p11. E5 explicitly registers `tb.top.master0.bw` and `memory_all`,
matching the spec cfg example without wildcards or inherited targets. Identity
is typed: point/group equal-text IDs remain distinct. Actual fixed public paths
are `/<top>/scene/ports[p]/dut/mon` and `/<top>/scene/{die0,die1,all_dmc,mixed}`.
Local reset changes only local statistics/epoch; source records/receipts continue.

## Complete configuration references

The [API tables](bw-mon-api.md) specify required/default/illegal behavior for all
protocol, fixed/dynamic bytes, credit, hint, identity/member/count, timeout, window,
episode and fit parameters. [Numeric/storage contracts](bw-mon-numeric-storage.md)
are authoritative for raw knownness, ranges, exact retention, representation
failures and resource accounting. Key facts for integration:

| Configuration | Object / unit / defaults and constraints |
| --- | --- |
| Sampling/time | All production scopes1fs/1fs; timestamps unsigned64 fs. Actual positive edges, maximum target2GHz; immutable40us system budget from original setup, never renewed by local reset. No extra drain beyond budget. |
| Setup | Raw logic64 point count required1..16384; group count default0, maximum4096. Known positive startup/missing-record timeouts default100ns/1ns; one actual expected edge starts each missing deadline across all levels. |
| IDs/members | Point default `__BW_AUTO__`, explicit nonempty unique overrides. Group ID required. Direct count known positive after dedup; total count includes free points. Exact/dot-segment Point prefix or exact Group membership, no cycles/recursive overlap. Same clock context/W/S/basis. Depth8, edges65536, parents16. |
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
narrowing. No user history slots/depth/RAM cap or wall-time speed gate exists.

Every scene records exact W/S/Q/N/span/K/fit/hint values, first clock phase, every
raw control/amount row, reset intervals, actual end, source/header/oracle/cfg hashes
and commands. Most scenes use2GHz, W10/S1ns or20/S2cycles, Q12ns/24cycles,
N3/span2ns or4cycles/K2 and explicit absolute0.01 fit tolerances/trend5, REL0.
E3/E4 exact-vector contexts declare their different clock/analysis configuration;
they do not overwrite the T4 baseline or pretend an absent next edge occurred.

## Public results and log/error location

[Public field manifest](../artifacts/acceptance/public-fields.json) and each view's
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

The [concrete error index](../artifacts/acceptance/error-catalog.json) links literal/
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
make test                         # component/current424 manifest
make acceptance                   #42 actual public scenes, FSDB and independent checks
python3 tests/acceptance/run.py --scene size_unknown --basis cycle
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

Full original input, CSV and compile/runtime traces are retrievable in each scene's
trace archive; FSDB, views, PNGs, references, tables and manifests remain directly
accessible. Captures are fresh real Verdi1500x850 client images; digital numeric
real rows avoid interpolation, and integer bytes/bounds independently establish
values. No simulation data or raster was altered. Scientific formatting exposes
exact distinctions such as152 versus151.99. Saved views reference nearby FSDBs.

The [concrete T6 checklist](../artifacts/acceptance/HUMAN-REVIEW.md) names actual
objects, intervals and expected observations across both bases and independent
variants. The [machine and human review ledger](../artifacts/acceptance/review.json) separates
automation, agent image inspection and **pending actual human review**. A human
entry must identify reviewer/date, actual objects/intervals, expected versus seen,
conclusion and discrepancies. One later attestation cannot retroactively claim
review of future assets. HTML illustration/probe screenshots and small resource
pilots do not stand in for real monitor/human/nominal-scale acceptance.

After a genuine named ledger entry is recorded, `python3 tests/acceptance/publish.py`
revalidates the existing assets and renders the current global human status in
`verification.json` and INDEX. It retains the entry only for the same asset
fingerprint; changed assets return the current status to PENDING. This command
retains the archived previous record on later pending republication without
adding duplicate archives, and does not create an attestation. Scene rows describe
automated results, and `human_review_at_generation` records their original generation-time state; neither
implies separate human approval of every scene. Original comparison/capture
manifests and expected/actual tables retain their historical PENDING text and
bytes. Do not use `--pack` for a review-status refresh.

`python3 tests/acceptance/test_publish.py` tests this public CLI with real frozen
assets copied into disposable directories, using explicitly SYNTHETIC records
only. It checks matching-fingerprint retention, changed-asset invalidation and
byte preservation without touching the real ledger, simulation or capture.

## Contract to evidence

| Clauses | Component anchors (current424 proof; historical408 retained) | Public scene evidence |
| --- | --- | --- |
| D1–D3/T1 | ns_bind, startup_*, group_matching, hierarchy_* | All42 use12 bound wrappers +4 groups/setup; exact IDs/free points/multi-parent mixed DAG. |
| D4–D5/T3 | protocol_recording, sample_view, credit_* | protocols ns/cycle: validX&ready0 known idle; credit valid0/flitv1/R0 definite send; fixed/dynamic amounts. |
| D6–D7/T4/T5-E1 | hierarchy_t4_ns_*, hierarchy_t4_cycle_*, retention/depth cases | Steady at2GHz64B:128/512/1024/768GB/s and64/256/512/384B/cycle; exact104ns increments under point/child reset/unknown size, plus upper reset. |
| D8–D9/T5-E2 | subns_vectors, cycle_window, reset_same_time_* | e2 both bases, isolated endpoints, start_stop, unknown/reset, clock_stop/frequency. E2 relative0 maps legal physical1ns after Ready. |
| D10/T5-E3 | episode_boundary/cycle/gaps/controls/final | e3_boundary: [80,102),confirm132, old-before-new132ns runtime markers in point+affected groups; zero/no_episode/truncated. |
| D11/T5-E3 | phase_delayed/hysteresis/actual_clock, metrics_delayed | e3_delayed: candidate120/confirm150, clipped[120,136), raw0 versus6.4 windows; varying/repeated stages. Fraction OLS uses actual publication times, K and independent qualification. |
| D12 | metrics_repeated/zero/quality/independent/stopped_history | Independent exact raw interval counts and population statistics for every delivered phase/episode; last steady PASS while whole CV FAIL, no earlier plateau substitution. |
| D13/T5-E4–E5 | report_* all48 keys/strict parsing/replays/barrier | e4 actual128/151.99FAIL and152PASS at effective152; e5 exact point/group IDs and only configured family sets; all conclusions/counters independently checked. |
| D14 | hint_* / credit_* | protocols + hints: NS hit during stopped cycle clock, unknown gap split, independent byte/metric counts. |
| D15/D17/T6/T8 | public point/group result aliases | Original FSDBs, portable public views, fresh real images, full expected/actual tables and explicit human ledger. Human remains pending. |
| D16/T7 | numeric_*, history_trace_*, variation_pending_retention, transport_growth, storage_failure_* | Component/resource evidence retains exact scope; full common/max/matrix evidence is a separate scale-ticket deliverable. Twelve-point scenes do not claim it. |

The scene index states source revisions, configurations, independent counts/results
and review status. Earlier per-ticket proof counts in API history stay historical;
this handoff links current durable proof and new scene evidence without conflating
automation, human review or scale targets.
