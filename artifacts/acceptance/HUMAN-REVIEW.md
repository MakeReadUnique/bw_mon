# Concrete human T6 review checklist — frozen objects

**Human review is PENDING.** These are actual generated objects, not future work.
This bundle was freshly rerun/captured on actual scene checkout `cd07c77fcb706022069a9496bcf72d4354c1d2f8`
(production18 byte-identical to fix56127495, independently qualified by427 cases/168 tops
at component checkout467b722; see final-component-proof) with42 unchanged
original input/configuration scenes and33 real Verdi images. Object names,
intervals and numeric targets below are unchanged. Its asset fingerprint is
`863af4f477409bf3e36af90f8fd7b2ffc7d008e2281f83fef759607482eeadee`;
earlier bundle signatures do not cover these regenerated objects.
Stopped/frequency clock views now also show die0/die1/mixed B/cycle rows; these
are0 in NS mode. Existing objects, time intervals and targets stay unchanged.
Automation passed42 scenes; twelve new images were separately inspected by an agent.
The original42 independent reference files also remain byte-identical. Historical
ledgers and qualification retain their original identities in review-history and
Git history; no prior record supplies approval for this new fingerprint. Open
the linked original FSDB and nearby public `.sav` with `./open.sh <view>`, inspect
actual images/values against the independent expected/actual table, then record
reviewer/date, named intervals, conclusion and any difference. A real attestation
must name this committed bundle and `review.json`'s asset fingerprint. It does not
approve future assets. The source of truth for exact values is the integer interval
and raw-input reference; numeric display is Scientific10, not interpolated curves.

Fixed actual data commit: [`59fc046a154945b6a6ae60220e663f7d5ee12bb6`](https://github.com/MakeReadUnique/bw_mon/tree/59fc046a154945b6a6ae60220e663f7d5ee12bb6/artifacts/acceptance).
Later guide/review-status commits do not change the named data identity. Record
this data commit and the exact fingerprint when supplying an actual attestation.

Common objects: p0...p11 (including freep10/p11), die0/die1, all_dmc and mixed at
fixed public instance paths. Most scenes use NS W10/S1 or cycle W20/S2; clock first
edge0.5ns. NS and cycle publication axes differ by0.5ns initially; consult each
actual interval rather than comparing equal labels as equal snapshots.

| Review family and exact interval | Expected observation | Actual objects to review |
| --- | --- | --- |
| **Steady full window**, NS[92,102), cycle[92.5,102.5)ns | Point128GB/s; die0/die1512; all1024; mixed768; full/known. Cycle64/256/512/384B/cycle. Freep10/p11 stay128. | NS [image](steady_ns/overview.png), [FSDB](steady_ns/waves.fsdb), [view](steady_ns/overview.sav), [table](steady_ns/expected-actual.md). Cycle [image](steady_cycle/clock.png), [FSDB](steady_cycle/waves.fsdb), [view](steady_cycle/clock.sav), [table](steady_cycle/expected-actual.md). |
| **Start and stop**,18...72ns, data[20,60) | Raw valid starts/stops; NS point at20/21/30/60/61/70ns gives0/12.8/128/128/115.2/0. Exact left/right cuts and history expiry; cycle holds its actual boundary schedule. | NS [image](start_stop_ns/overview.png), [FSDB/view](start_stop_ns/open.sh), [table](start_stop_ns/expected-actual.md). Cycle [image](start_stop_cycle/overview.png), [FSDB/view](start_stop_cycle/open.sh), [table](start_stop_cycle/expected-actual.md). |
| **Changing/repeated phases**,20...153ns | Original bytes ramp, plateau, fall, short gap, repeated plateaus. Candidate boundary precedes K confirmation; no phase labels input. Last steady raw128 passes while whole CV43%+ fails, simulation continues. Earlier ramp/fall times persist. | NS [phase image](varying_ns/phase.png), [final image](varying_ns/episode.png), [FSDB](varying_ns/waves.fsdb), [views](varying_ns/open.sh), [table](varying_ns/expected-actual.md). Cycle [image](varying_cycle/phase.png), [FSDB/views](varying_cycle/open.sh), [table](varying_cycle/expected-actual.md). |
| **Actual point reset**,103.9...104.1ns; inspect104/105/115 | Point0 epoch advances/rewarmup; source raw104 excludes only its transfer. Parent history/sequence continues with complete known bytes and member-reset coverage, not automatic invalidity/target scaling. | NS [image](point_reset_ns/quality.png), [FSDB/views](point_reset_ns/open.sh), [table](point_reset_ns/expected-actual.md). Cycle [FSDB/views](point_reset_cycle/open.sh), [table](point_reset_cycle/expected-actual.md). |
| **Child statistics reset alone**,103.9...104.1ns | Only die0 epoch/history/episode resets; its104ns raw256B/4 still serves both parents. All/mixed retain original histories/process and no actual-point-reset coverage. | NS [image](child_reset_ns/quality.png), [FSDB/views](child_reset_ns/open.sh), [table](child_reset_ns/expected-actual.md). Cycle [FSDB/views](child_reset_cycle/open.sh), [table](child_reset_cycle/expected-actual.md). |
| **Upper statistics reset alone**,103.9...104.1ns | Only all_dmc epoch/rewarmup changes. Shared child, point and mixed supply continue; this does not create member point-reset coverage. | NS [image](upper_reset_ns/quality.png), [FSDB/views](upper_reset_ns/open.sh), [table](upper_reset_ns/expected-actual.md). Cycle [FSDB/views](upper_reset_cycle/open.sh), [table](upper_reset_cycle/expected-actual.md). |
| **Unknown transfer size alone**, raw104ns, windows105...115, final133ns | Definite event remains; known subtotal propagates. Window full can coexist BC0/EC1, later window recovers; old whole e2e stays unavailable. Later complete last-steady may still pass independently. | NS [quality](size_unknown_ns/quality.png), [final](size_unknown_ns/episode.png), [FSDB/views](size_unknown_ns/open.sh), [table](size_unknown_ns/expected-actual.md). Cycle [FSDB/views](size_unknown_cycle/open.sh), [table](size_unknown_cycle/expected-actual.md). |
| **Unknown valid alone**, raw104ns/windows105...115 | Event and byte observations incomplete, known other-member contributions retained. Unknown is not an invented zero/known idle. | NS [image](valid_unknown_ns/quality.png), [FSDB/views](valid_unknown_ns/open.sh), [table](valid_unknown_ns/expected-actual.md). Cycle [FSDB/views](valid_unknown_cycle/open.sh), [table](valid_unknown_cycle/expected-actual.md). |
| **Unknown reset alone**,103.9...104.1ns/windows104...115 | Epoch stays0, unknown interval/record propagates BC/EC incompleteness, no known-reset coverage. Quality returns after expiry without repairing old process. | NS [image](reset_unknown_ns/quality.png), [FSDB/views](reset_unknown_ns/open.sh), [table](reset_unknown_ns/expected-actual.md). Cycle [FSDB/views](reset_unknown_cycle/open.sh), [table](reset_unknown_cycle/expected-actual.md). |
| **Stopped clock alone**, last79.5/next100.5ns; resume101ns | NS history expires; cycle seq/window stays at79.5 until actual new publications. At101:1280B/20cycles over30.5ns=41.9672GB/s but64B/cycle. No fabricated edge/tail or missing-frame error. | NS [image](clock_stop_ns/clock.png), [FSDB/views](clock_stop_ns/open.sh), [table](clock_stop_ns/expected-actual.md). Cycle [image](clock_stop_cycle/clock.png), [FSDB/views](clock_stop_cycle/open.sh), [table](clock_stop_cycle/expected-actual.md). |
| **Frequency change alone**, last fast79.5/first slow80.5ns; fully slow90...104 | Actual clock period doubles. Full slow point64GB/s, still64B/cycle; all512GB/s/512Bcycle. Mixed-rate denominators use true timestamps. | NS [image](frequency_ns/clock.png), [FSDB/views](frequency_ns/open.sh), [table](frequency_ns/expected-actual.md). Cycle [image](frequency_cycle/clock.png), [FSDB/views](frequency_cycle/open.sh), [table](frequency_cycle/expected-actual.md). |
| **Independent NS hint**,85...95ns inside stopped clock | Backpressure live condition starts85/hits87/ends95duration10ns while cycle snapshot stays fixed. Performance counters remain separate; this is not proof of pending demand. | [Image](hints_cycle/hints.png), [cycle FSDB/views](hints_cycle/open.sh), [cycle table](hints_cycle/expected-actual.md); [NS FSDB/views](hints_ns/open.sh), [NS table](hints_ns/expected-actual.md). |
| **Three protocol discrimination**,59...66ns | P1 validX/ready0 proves known idle/complete events. P2 valid0/flitv1/lcrdv0 still counts while credit remains trusted (C13 at61ns). Fixed/dynamic accounting unchanged. | [Image](protocols_ns/protocols.png), [NS FSDB/views](protocols_ns/open.sh), [table](protocols_ns/expected-actual.md); [cycle FSDB/views](protocols_cycle/open.sh), [table](protocols_cycle/expected-actual.md). |
| **Zero versus no process**,20...53ns | Zero-byte events form a valid0e2e/sigma process but CV zero-mean unavailable. All-idle has no episode, not passing0. | [Zero image](zero_ns/episode.png), [no-process image](no_episode_ns/episode.png), [zero NS table](zero_ns/expected-actual.md), [no-process NS table](no_episode_ns/expected-actual.md); [zero cycle](zero_cycle/open.sh), [no-process cycle](no_episode_cycle/open.sh) with nearby tables. |
| **Unknown tail at truncation**,109.5...110.000001ns | No next edge; tail/e2e unavailable and final statusTRUNCATED. Earlier plateau cannot stand in for a valid final representative. Numeric backing0 is not a pass. | [Image](truncated_cycle/episode.png), [cycle FSDB/views](truncated_cycle/open.sh), [table](truncated_cycle/expected-actual.md); [NS FSDB/views](truncated_ns/open.sh), [table](truncated_ns/expected-actual.md). |

Supplemental exact-vector objects (separate legal sampling contexts):

- **E2**, physical11/12/13/21/23ns (relative10/11/12/20/22): [image](e2_ns/overview.png),
  [NS FSDB/view](e2_ns/open.sh), [NS table](e2_ns/expected-actual.md),
  [cycle FSDB/view](e2_cycle/open.sh), [cycle table](e2_cycle/expected-actual.md).
  Check320/384/384/256/256B and32/38.4/38.4/25.6/25.6GB/s. The actual11ns input
  transfer is excluded from the11ns window. [Isolated NS](isolated_ns/open.sh) and
  [cycle](isolated_cycle/open.sh) tables additionally check boundary inclusion/expiry.
- **E3 episode**,80...132.000001ns: [image](e3_boundary_ns/episode.png),
  [FSDB/view](e3_boundary_ns/open.sh), [table](e3_boundary_ns/expected-actual.md).
  Old[80,102)256B/3events/22ns confirms132; new132ns transfer starts separately,
  with current128B while the immutable old packet remains256B. Runtime point/group
  marker checks prove the old-before-new order.
- **E3 phase**,120/150/136ns in a separate context: [candidate/confirm image](e3_delayed_ns/phase.png),
  [final image](e3_delayed_ns/episode.png), [FSDB/views](e3_delayed_ns/open.sh),
  [table](e3_delayed_ns/expected-actual.md). Candidate120 confirms150, final
  clip[120,136): raw0/16ns versus two6.4 windows. Do not merge this with[80,102).
- **E4**, complete1...101ns: [152 image](e4_boundary_ns/episode.png),
  [151.99 image](e4_below_ns/episode.png), [128 image](e4_low_ns/episode.png).
  Each adjacent folder has original FSDB/view/table. Effective lower152:
  actual152PASS,151.99/128FAIL; all simulations continue.
- **E5**,20...153ns: [image](e5_ns/episode.png), [FSDB/views](e5_ns/open.sh),
  [table](e5_ns/expected-actual.md). Exact registered point `tb.top.master0.bw`
  and group `memory_all` receive only their configured metric families; no inheritance.

Record any discrepancy even if automation passed. Human review does not certify
future scale runs, different source/cfg, tool-probe images or HTML illustrations.
The [ledger](review.json) is the only human status record; all entries remain
pending until genuine named review/attestation is received.
