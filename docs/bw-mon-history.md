# Exact history acceptance

The revised [history acceptance ticket](https://github.com/MakeReadUnique/bw_mon/issues/31)
separates history depth, elapsed time, window expiration, representation, evidence
ownership and transport retention. Its H1–H7 requirements implement the current
D16/T7/T8 clauses of the [implementation spec](https://github.com/MakeReadUnique/bw_mon/issues/13).
The canceled twelve-cell COMMON/MAX long-run matrix is historical evidence. Its
six completed COMMON cells are not a completion counter for this matrix.

The [completed shared campaign](../tests/scale/revised_evidence/final-campaign/README.md)
passed all seven history cases, both full-scale H6 cases,15 directed H5/H7 checks
and independent replay in cold and cached modes. The complete two-ticket suites
took906.636s/829.518s; the longest new history case took20.273s, within300s.
Both deep cases actually retained80,000 event segments in p0 and the group,
and one exact merged run in p1. The pending case retained30,000 samples in each
variation queue and released both. Full per-case timings, observed state and
resource limits are in the linked measured summary.

## Reproduce the history cases

Use the shared, serial qualification runner for final cold/hot timing and the
combined topology/history result. Individual history cases use the same bounded
runner:

```sh
python3 -m unittest discover -s tests/scale -p 'test_history*.py'
python3 tests/scale/history_revised.py \
  history-revised-ns-seeded history-revised-cycle-seeded \
  history-revised-ns-expiry history-revised-cycle-expiry \
  history-revised-ns-deep history-revised-cycle-deep \
  history-revised-pending --output-root /tmp/bw-history-revised
```

The combined entry is `python3 tests/scale/revised_suite.py quick|full
--output-root PATH --cache-mode cold|hot`. Run cold and hot against the same
unchanged source and output root. The portable archive entry is
`python3 tests/scale/revised_evidence.py verify DIRECTORY`; the campaign bundle
is [revised_evidence/final-campaign](../tests/scale/revised_evidence/final-campaign).

Run these commands serially with other qualification work. The coordinated
campaign holds one `qualification.lock` for costly generation, compilation,
simulation and verification. The runner enforces a 300-second end-to-end budget
per history case, retains failed/timed-out attempts, terminates live process
children, and records generation, compilation, initialization, simulation and
verification separately. Initialization is measured from the flushed Ready
marker; its polling resolution is recorded. Cache reuse requires the exact
input, source, options, native headers and tool fingerprints and binary hash.
A cached compilation is recorded as zero current elapsed time with its original
build receipt retained.

The daily set uses the two seeded cases and the pending-suffix case, together
with the topology ticket's actual tens-to-hundreds-of-points cases. It must meet
120 seconds hot / 300 seconds cold in total. Complete qualification includes all
seven history cases, both full-scale shared cases and required evidence audits,
with a serial cold and hot limit of 1,800 seconds each. Per-case success alone
cannot satisfy that combined limit. These are acceptance-tool budgets, not a
monitor overhead benchmark or a product memory cap.

## Property and evidence mapping

The machine-readable mapping is
[history-coverage.json](../tests/scale/history-coverage.json). The completed qualification supplies actual verification receipts for every required profile and the
shared H6 case; old profile names cannot meet those requirements.

| Requirement | State and invariant | Executable evidence and independent expectation |
| --- | --- | --- |
| H1: half-open windows, dense updates, short/mid widths, W not divisible by S | Each scope's original records and published windows have independent counts and quality. Current raw totals include the right-edge event; the window excludes it. | `*-seeded`: NS W7/S3 and cycle W17/S3; `*-expiry`: NS W127/S3 and cycle W257/S3. The expanded original-event oracle checks every raw record and every window field. `history_trace_ns/cycle` add the literal 17-edge W3/S2 event table. |
| H2: maximum widths and time boundary | Actual first edge is 0.25 ns. Exactly 80,000 edges occur by 40,000 ns, with 79,999 complete cycles. No extra edge or positive-time drain exists. | `*-deep`: actual public two-point/one-group scenes at 2 GHz. NS W40000/S1 first becomes full at the endpoint; cycle W80000/S1 stays warmup through publication 79,999. Every original receipt, publication and final truncated episode is checked. Source-qualified original COMMON long rows supplement this evidence. |
| H3: real fragmented capacity and reuse | Event history, actual-clock history and pending variation history are separate states. No counter or prebuilt history is injected. | `*-deep` must measure exactly 80,000 event segments in p0 and the group; p1 must measure one merged segment. `*-expiry` alternates legal clock intervals and requires four complete drain/regrow cycles, final event storage zero, and explicit event/clock high-water thresholds. |
| H4: exact compressed representation | Expanding observed runs must reproduce the original retained event timestamps, edge positions, bytes, events, completeness and reset flags, in order. | Public differential checks plus independent expansion of `storage-runs.txt`. Seeded/expiry snapshots include partial cuts, run boundaries and singletons; deep p1 expands one run to 80,000 original events. The literal trace cases check unknown/reset markers and their recovery. |
| H5: controls, silence and pending ownership | A recovered window does not repair the old incomplete episode; an actual next edge determines the tail. Confirmation samples outside the episode must be excluded without losing its owned prefix. | Seeded cases include unknown bytes/events, variable clock, a legal stop and known-zero recovery. Expiry episodes check all four original first/last/tail/Q boundaries. `history-revised-pending` retains at least 30,000 pending samples in both queues and selects exactly the original three samples at 1/2/3 ns, mean16/sigma0/CV0; final queues are empty. Existing `phase_delayed`, `metrics_stopped_history`, reset and literal history contracts supply directed N/K, delayed clipping, point/group reset and stop cases. |
| H6: multi-consumer transport | A fast consumer may advance while a slower consumer retains original frames and controls. Input ACK follows core acceptance; all consumers must ACK before release. | Shared full-scale M4/H6 topology profiles, including sixteen direct parents and both window bases. Their one actual evidence bundle is referenced by both tickets. `transport_growth` supplies the separate directed 4,096-frame backlog contract. Small history runs do not qualify H6. |
| H7: numeric boundaries | Integer arithmetic remains exact through large cumulative bytes, timestamps and sequence progression. Boundary operations must reject under/overflow and unknown numeric inputs. | Deep p0 alternates 4,294,967,294 and 4,294,967,295 bytes, reaching 343,597,383,560,000 actual bytes. Every fixture checks known unsigned64 add/multiply/subtract/time literals. Existing numeric arithmetic/subtract/transport/core contracts cover error boundaries; the real public deep scenes provide the integration complement. |

## Fixed scenarios and independent oracle

All six event-table cases instantiate two `bw_point_mon` modules, a real
`bw_group_mon` over both leaves, and `bw_mon_setup`. Both point byte inputs are
dynamic and all actual inputs enter through these public modules. The group
sum cannot hide the deep alternation: p1 is constant64B, so the group alternates
with p0. Points and group each consume all original records and publish all
planned results. Their transport queues must be empty at the observation end.

| Profile suffix | Actual clock/input | Width/stride | End condition |
| --- | --- | --- | --- |
| `ns-deep`, `cycle-deep` | 80,000 real edges, 0.25 ns first edge, 0.5 ns period; p0 alternates maximum legal byte sizes; p1 constant64B | 40000ns/1ns; 80000cycles/1cycle | Exactly40,000ns; no fabricated tail; three truncated incomplete-duration episodes |
| `ns-expiry`, `cycle-expiry` | 8,192 edges; alternating0.5/1ns intervals; four blocks of1,024 active then1,024 known-idle edges | 127ns/3ns; 257cycles/3cycles | Four observed empty-history checkpoints, four normally completed episodes per scope, final event histories empty |
| `ns-seeded`, `cycle-seeded` | Fixed seed310026; 1,024 real edges; distinct leaf values, zero-byte transfers, unknown bytes/events,0.5/1ns intervals and one50ns stop | 7ns/3ns; 17cycles/3cycles | Last128 edges known idle, then40ns; final windows recover while old p0/group episodes remain incomplete |
| `pending` | Existing one-point public fixture: six8B transfers, one real idle edge, then actual ns timer publications | 1ns/1ns, Q30000ns, N3/K60000/minimum span2ns | Exactly30,003 publications; original episode [0.25,3.25)ns; confirmation30003.25ns; retained suffix released |

Event cases explicitly enable episodes and phases with N3/K4, minimum span2S,
Q30ns or60cycles, steady enter/exit ABS0/REL0, RMS enter/exit ABS1e-6/REL0 and
trend ABS1/REL0. They use valid-only interfaces; unsupported handshake/credit
hints remain disabled. Mixed protocols and enabled supported hints remain
covered by the source-qualified COMMON evidence and the existing public
integration suite. Waves are off. `input.json`, `event-input.txt`, generated SV,
`expect.cfg`, per-scope raw/window references and final `expected.csv` retain
all configuration and original input data.

The Python oracle uses exact integer prefix sums over individually expanded
input events and binary search on the original timestamps. It never calls the
production merger, clipping code, variation accumulator or DUT history query.
Its real comparison tolerance is separately fixed at absolute1e-9 plus
relative1e-12; integers and quality are exact. A fixture checker reads independent
reference rows and requires complete consumption of both streams. Final summary,
episode/report counts, ordering, diagnostics and the all-scope completion barrier
are also audited. An independent rational least-squares reference derives every
expected phase's identity, candidate/confirmation boundaries and final clipping
from the original published-window model. Every configured metric must appear
exactly once at its expected scope/epoch/episode identity, with independent value,
conclusion and summary counters. Stored snapshots must match the complete planned
per-scope checkpoint sequence and final endpoint; empty or missing exports fail.
Negative regressions remove phases, remove scope snapshots, substitute empty
snapshots, duplicate checkpoints/checks and corrupt report counters. Missing output, mismatches, incomplete references or a timeout
cannot become PASS.

The fixture's read-only queue observation is instrumentation for this acceptance,
not a new product API. `storage-runs.txt` is actual representation under test.
The auditor expands those runs and derives expected retained positions from
original events and independent window scheduling, including the actual clock
boundaries. It observes event/clock segment peaks, phase-sample peaks, pending
run peaks, pending represented-sample peaks and final retained states separately.
The variable-clock expiry probe measured a clock-segment peak of130 and129
segments retained at the end, plus a pending peak of20 runs/20 samples. These
are the clock and fragmented-pending depths actually exercised; they are not
80,000-segment claims. The original maximum-width baseline has a constant clock
(one clock segment), and its control variant has three clock intervals; the
variable-clock case adds repeated clock-storage growth and expiration beyond
those original conditions. The independent source review verifies that each
queue grows from real accepted inputs through its own checked append path.
The 30,000 pending suffix samples compress into one run in the measured fixture;
this is deep pending ownership coverage, not 30,000 fragmented pending runs.
No floating-point replay order or production history behavior is changed.

## Why the decomposition is valid

`bw_stats_core` owns its event, clock, phase and variation histories per instance.
A group consumes original direct-member increments, with their original edge and
timestamp, before applying its own independent window and analysis state. Depth
can therefore be stressed by three real scopes without duplicating the same
80,000-segment sequence across every maximum-topology scope. The observed
80,000 segments prove storage growth, whereas the original constant-flow runs
largely exercised merged runs. The smaller-window scenes separately prove that
expired storage is actually removed and can grow again.

Registration, shared scheduling, transport, acceptance-before-ACK and reporting
are coupled across scopes. Their maximum-scale proof remains in the topology
ticket's actual short public-entry scenes. H6 is a required joint case, not an
inference from the instance-local histories. The resource report distinguishes
full-scale short-sequence RSS, three-scope fragmented-history RSS, pending-suffix
RSS and transport retention. It never adds them and calls that a measured
full-scale long-history peak. Any extrapolated resource estimate must state its
assumptions explicitly.

## Historical evidence and source applicability

The immutable [six COMMON bundles](../tests/scale/history_evidence/final-campaign/README.md)
retain their original source, commands, actual inputs/results, native dependencies,
RSS and independent audit. Offline replay at the revision baseline passed all
614,016,000 raw checks and307,132,157 window checks, zero differences. Their
18 production files were then identical to the current baseline. The current
portable audit replays their original frozen source:

```sh
python3 tests/scale/history_evidence/final-campaign/verify.py
python3 tests/scale/history_evidence/final-campaign/test_verify.py
```

Startup optimization splits the monotonic global Ready wait from the subsequent
per-instance identity/readiness wait in the point/group wrappers. Once that
change is integrated, the old bundles are no longer described as having the same
complete production source. Reuse applies to the unchanged history/metric
semantics and long-window original-input evidence; current public-entry cases,
component checks and the reviewed startup change qualify the changed path.
The revised maximum-topology fixture also adds collector-delay and read-only
storage-growth observations behind `BW_MON_TEST_SCHEDULING` in the group/package
sources. That define is absent from these history cases and ordinary production
compatibility cases; the revised quick/MAX topology fixtures enable it. The final source comparison therefore has fifteen unchanged
production files and three textually changed files (point, group and package);
it must retain the reviewed default-path applicability of those changes.
Exact changed-file hashes/diffs and source applicability belong in final
qualification. `--current-source` is valid only when all original production
hashes actually match; it must fail after a production change.

The historical checkpoint still says six of twelve because it describes its
original date. The subsequent [user stop record](https://github.com/MakeReadUnique/bw_mon/issues/31#issuecomment-6414148225)
keeps MAX ns-long, cycle-long and ns-short `OPERATOR_INTERRUPTED`; MAX cycle-short,
ns-control-clock and cycle-control-clock were canceled before starting. None is
promoted to PASS. The old `history.py` remains an explicit specialist entry;
it is absent from revised daily/full execution. No canceled scheduler is
restarted or included in the completion gate.
