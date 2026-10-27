# Revised maximum-topology acceptance

> 交付目录已精简：当前 PR 保留源码、最终摘要和截图。下面的历史证据链接指向固定提交；本地查看/复验请先看[证据与复现说明](bw-mon-evidence.md)。

The current [topology ticket](https://github.com/MakeReadUnique/bw_mon/issues/30)
uses M1–M5 together with the [history ticket](bw-mon-history.md). The maximum
16,384 points, 4,096 groups, eight levels, 65,536 direct edges and sixteen direct
parents remain real public-module requirements. The canceled four 40 μs MAX
runs retain their incomplete identities; their completion counters do not apply
to this matrix.

The [completed frozen campaign](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/revised_evidence/final-campaign/README.md)
passed all four serial suites: daily96.596s cold /25.528s cached and
complete906.636s cold /829.518s cached. Both maximum profiles check all65,536
direct identities and10,485,760 raw receipts each, with5,242,876 NS windows and
10,465,274 cycle windows, zero differences. The slowest maximum run across both
modes was340.344s against600s. Independent portable replay also passed; PR and
issue review status is separate from these completed measurements.

## Reproduce the revised suites

The commands run on Python 3.6.8 or later with the installed VCS W-2024.09-SP1,
GCC and GNU time tools. The run manifest records the actual interpreter path,
versions, executable hashes, native headers, compiler options and host load.
Use one output root and unchanged sources for cold and hot measurements:

```sh
python3 tools/evidence.py restore common
python3 tests/scale/revised_suite.py quick --cache-mode cold --output-root /tmp/bw-revised --lock /tmp/bw-qualification.lock
python3 tests/scale/revised_suite.py quick --cache-mode hot --output-root /tmp/bw-revised --lock /tmp/bw-qualification.lock
python3 tests/scale/revised_suite.py full --cache-mode cold --output-root /tmp/bw-revised --lock /tmp/bw-qualification.lock
python3 tests/scale/revised_suite.py full --cache-mode hot --output-root /tmp/bw-revised --lock /tmp/bw-qualification.lock
python3 tests/scale/revised_evidence.py archive /tmp/bw-revised --destination /tmp/bw-revised-proof
python3 /tmp/bw-revised-proof/verify.py verify /tmp/bw-revised-proof
```

The suite holds its lock through generation, compilation, simulation and all
required recorded-data audits. Lock waiting is recorded separately. Other
qualification commands must use that same lock. Individual diagnosis uses
`topology_revised.py topology-quick-ns|topology-quick-cycle|topology-max-ns|topology-max-cycle
--output-root PATH`; wrap individual invocations in `flock` when sharing a host.
No command above resumes or schedules an old campaign.

Daily regression uses two real 128-point/32-group topology cases, two seeded
history cases and the pending-suffix case. The complete suite adds both maximum
topologies, all seven history cases, fifteen directed H5/H7 component cases,
frozen-source COMMON replay and independent replay of every new case. Shared
M4/H6 scenarios occur once per suite. The exact gates are 120 seconds hot /
300 seconds cold daily, 600 seconds per maximum case, 300 seconds per history
case and 1,800 seconds for a complete serial suite. Timeouts, missing receipts,
differences and over-budget runs remain incomplete.

`bounded.py` counts generation, compilation, initialization, simulation,
verification, process cleanup and orchestration in the end-to-end result. Ready
is a flushed marker with recorded 50 ms polling resolution. VCS may leave a
short DNS helper during shutdown; bounded cleanup is included in stage time
and persistent children are terminated and rejected. Cache reuse matches all
input/source/tool/header/options fingerprints and the simulator launcher plus
its native shared payloads. Component builds are forced in both full-suite
modes because their older runner has a weaker cache key.

## Fixed input and actual public paths

Both maximum cases instantiate every declared scope through `bw_point_mon`,
`bw_group_mon` and `bw_mon_setup`. They have 512 actual edges at 2 GHz: first
0.25 ns, last 255.75 ns, end exactly 256 ns. Traffic is active for edges1–384;
128 further idle edges provide real tail, silence confirmation, recovery and
settlement. There is no extra edge, internal history preload or early finish.
NS uses W16/S1 ns; cycle uses W128/S1 cycles. Both enable Q30ns/60cycles,
N3/K4/minimum-span2, ABS steady0, RMS1e-6, trend1, all REL0. All12 report rules
are configured per scope. Waves are off. Supported handshake/credit hints use
4ns/8cycles; credit capacity/known initial balance16 and NEXT_CYCLE returns
remain enabled for credit points.

Point protocols cycle through valid-only, valid-ready and credit. Every point
uses its dynamic public byte input: `point_index + 1 + 3*(edge_index % 2)`.
This gives distinct leaf weights and actual nonmergeable histories while
steady complete windows remain available. P0 has unknown bytes at edge193,
a known interface reset [100.1,101.1)ns, and group0 has its independent statistics
reset [128.1,129.1)ns. Ancestors keep their previous history and raw supply.

Group0 contains points0–15. Groups1–7 each add fifteen fresh points to the
previous group, giving a depth-eight path with121 leaves at group7. Groups8–22
each include group0 plus fifteen fresh points: group0 has sixteen direct
parents including group1. Remaining groups use sixteen direct point members.
Every group has sixteen direct edges, totaling65,536; recursive leaf sets are
disjoint within each group. Point16383 is ungrouped and fully checked.
[The machine-readable mapping](../tests/scale/topology-coverage.json) records
fixed profiles, independent topology/leaf-set definitions and evidence names.

Every public raw publication is retained by the checker until the matching
core acceptance receipt. This distinction matters when a delayed collector
publishes several records at one physical time. The latest raw publication
need not be the payload named by an earlier acceptance receipt. Every receipt,
raw timestamp/edge, cumulative count, quality flag, epoch, published window and
result sequence is checked. All actual direct member identities are exported
through public registry queries and compared with the independent input graph;
a two-member substitution with equal total byte weight is explicitly rejected.
The checker never obtains its expected leaves or history from the DUT.

Integers/quality are exact. Real comparisons use ABS1e-9 + REL1e-12. The Python
reference uses original input positions and independent leaf sums; generated
SV applies the same independent input model online. Final CSV/reference/diffs,
all-scope report barriers, episode first/last/tail/confirmation/duration/rate,
phase sequences, all12 metric records and final transport release are audited.
Performance FAIL/WARNING conclusions are expected for some configured targets;
correctness requires zero independent differences.

## Why the decomposition preserves the required properties

| Original requirement | State and invariant | Revised evidence and independent expectation |
| --- | --- | --- |
| D16/T7 maximum registration and topology | Actual registered identity, recursively disjoint membership, raw time and sequence are shared routing properties. | M1/M2: both maximum cases check20,480 scopes and all65,536 actual direct identities, every raw receipt/window, depth8 and subgroup fanout16. Counts come from input graph/leaf sets, not registry-derived expectations. |
| Local statistics and original-time hierarchical sums | Each `bw_stats_core` owns its own event/clock/phase/variation histories. Groups sum incoming raw increments and accept them before acknowledging input; they do not consume child window results. | M3: differentiated traffic plus p0 unknown/reset and group0 statistics reset; every scope independently checks original raw increments, cumulative epoch totals and windows. Ancestors neither restart nor lose the child's supply. |
| Shared scheduling, history growth and unequal consumers | Routing/reporting/settlement are shared; these cannot be established by a few deep-history scopes. | M4/H6: actual automatic group8 collector pauses [99,102)ns. At101.5ns fast group1 ACK203 while slow group8 ACK198; subgroup0 retains exactly five frames and two controls, with real fragmented history. NS timers and cycle boundaries remain behind missing acceptance. Release processes original timestamps, catches up to204, and leaves no unread frames/controls. |
| Long cumulative/time/history boundaries | Local histories, clipping cursors and pending evidence are independent scope state; their depth does not depend on the number of other registered scopes. | H1–H7: actual2GHz/80,000-edge/40μs cases at three scopes,80,000 nonmergeable segments, an independently expanded merged80,000-event run, growth/expiry/regrowth, clocks, quality, N/K/Q and arithmetic boundaries. W80000cycles correctly remains warmup; W40000ns first becomes full at the endpoint. |
| Final reports and resource accounting | Shared reports require every registered scope to settle once; transport releases after all direct consumers acknowledge. | M1/M5: complete typed final records, summary counters, all scope/resource rows and final release checks. Deep-history and maximum-scope resources remain separate measured experiments. |

These invariants are established from the implementation ownership and actual
cross-scope checks, not inferred from module names or small-scale success.
Repeating80,000 edges at all20,480 scopes would repeat local history arithmetic;
it would not replace the explicitly tested shared-state interactions. No
claim is made for the unmeasured simultaneous maximum-scope/maximum-fragmented-
history memory peak. H3 supplies actual deep storage, rather than treating
80,000 equal inputs as80,000 stored segments.

The acceptance-only `BW_MON_TEST_SCHEDULING` flag exposes a gate before the real
collector loop and read-only resource-growth counters. It never edits a frame,
receipt, clock, history, total or ACK. All normal collector/core/report code runs.
The flag is off in ordinary production and the broad component/E2E campaign;
topology quick and MAX fixtures explicitly turn it on. The default runtime's
Ready optimization splits its monotonic global barrier from local string
identity waits, avoiding VCS's global cross-module string-callback fanout while
preserving the readiness condition.

## Resource and evidence boundaries

Each stage records GNU time-v maximum RSS. Simulator, compiler, Python
reference/checker and archive work are separate processes and measurements.
Per-scope resource CSV rows record observed history/clock/pending/transport
states and final release. The growth instrumentation additionally records the
largest individual queue of every resource type, including transient core
controls/timers, registry, report and scheduler storage. Sums of per-scope
maxima are labeled as sums and are not simultaneous global high-water marks.
RSS includes simulator/checker overhead; it is not a direct product allocation
counter. No fixed memory cap, dropped events or approximate accounting exists.

The final campaign is [revised_evidence/final-campaign](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/revised_evidence/final-campaign).
Its four cold/hot suite receipts and portable verifier are the completion gate;
individual exploratory passes are not substituted for the final source-frozen
suite. Source snapshots include the exact fixtures and native build receipts.
The archived verifier regenerates all independent inputs and rechecks actual
streams without VCS or the original temporary paths. Packaging is separately
measured; the required independent recorded replay is already included in each
suite's budget.

The original four MAX jobs were stopped by the user and never completed. Their
[original receipts](https://github.com/MakeReadUnique/bw_mon/blob/b22e32e1beb704beb290e65f7af20bbe44065a34/tests/scale/evidence/maximum-qualification/continuation.json)
and preparation archives keep their historical checkpoint states. The later
cancellation is recorded in the [topology ticket](https://github.com/MakeReadUnique/bw_mon/issues/30).
The old `maximum.py`/`qualify_maximum.py` workflow is an explicitly selected
legacy research workflow, with no role in the new completion gate. Similarly,
the six completed COMMON history rows remain genuine historical proof and the
six MAX history rows keep their interrupted/not-started identities.
