# Bandwidth monitor integration and public results

The current implementation covers ns and local-cycle observation-point windows
from [绑定观测点并发布 ns 滑窗带宽](https://github.com/MakeReadUnique/bw_mon/issues/14)
and [cycle 滑窗、停钟与变频](https://github.com/MakeReadUnique/bw_mon/issues/16),
and three-protocol accounting from
[三类接口的逐传输计量与观测缺口](https://github.com/MakeReadUnique/bw_mon/issues/15).
Scene-specific point/group e2e, last-steady, ramp/fall and variation checks are described in
[Expectation configuration and reports](bw-mon-expectations.md). The remaining
implementation tickets extend this same public contract.

## Compile and start

Compile `rtl/bw_mon_pkg.sv`, then `rtl/bw_check_report.sv`, then the other
`rtl/*.sv` files, plus `rtl/bw_slot_settlement.c`. The report package must precede `bw_mon_setup.sv`. All production
builds need `+vpi`, `-debug_access` (or waveform `-debug_access+all`), the installed
VCS include directory through `-CFLAGS -I<VCS>/include`, `+incdir+rtl` and `-assert svaext` for the package headers and scheduler assertions, including point-only setups. Headers are included by the package or public modules and are not standalone
compilation units. All production
scopes use `timeunit 1fs; timeprecision 1fs`; timestamps are unsigned 64-bit integer
femtosecond ticks, read directly with `$time` in that scope. A nanosecond is
1,000,000 ticks. Do not override production time units or precision.
The private native adapter preserves ordered reset input and writable same-time
closure; [scheduling and build details](bw-mon-scheduling.md) include its tested
tool contract and public regressions.

```systemverilog
// Once for every target module instance of this type:
bind data_port bw_point_mon #(
  .WINDOW_WIDTH(10), .UPDATE_STRIDE(1), .FIXED_BYTES(64)
) bw (.clk(clk), .reset_n(reset_n), .valid(valid));

// Once in the testbench; discovers every point, including ungrouped points:
bw_mon_setup bw_setup();

initial begin
  wait (bw_mon_pkg::monitor_ready);
  // Begin traffic on an actual sampling edge strictly after ready's time.
end
```

Default Point IDs are exactly the public monitor instance hierarchy, generated
once in the unnamed `bw_point_mon` initial block. For example, `tb.port0.bw`.
`POINT_ID("my.point")` explicitly overrides the identity while `monitor_path`
retains the actual instance path. An explicit empty string is an error. Reset
never re-registers an identity. The reserved default parameter value is
`"__BW_AUTO__"`.

Registration and membership calls are legal only at actual time zero, including
finite initial, `#0`, NBA and subsequent same-time scheduling chains. The library
checks actual time in its own time scope, even when the caller uses a coarse
timescale. The setup seals configuration at the first representable positive
time step, resolves forward references, deduplicates members and prepares every
scope, initial reset snapshot and report registration in that same time slot.
It then publishes the persistent `bw_mon_pkg::monitor_ready` exactly once.
Initial reset and stopped clocks do not delay startup.

The published `bw_mon_pkg::measurement_start_ticks` is the common measurement
start T; use it rather than assuming a fixed 1 fs start. No sampling edge at or
before T contributes. Without a local reset, ns publications begin at T+S;
the startup snapshot has result sequence zero. All scopes share the inclusive
T+40 microsecond budget, which a local reset cannot renew. Reports retain
absolute timestamps. The `BW_READY` record gives actual point/group counts,
T, time scale, budget duration and absolute deadline.

One setup and at least one reachable point are required when monitoring is
connected. Empty scopes, missing/duplicate setup, invalid identities or topology,
positive-time registration/member calls, and ending before ready are terminating
startup errors; they suppress normal completion summaries. No manual count,
finish call or startup timeout remains.

## Initial configuration

| Object | Parameter | Type / unit | Requirement and illegal behavior |
| --- | --- | --- | --- |
| setup | none | one `bw_mon_setup` instance | Actual point/group counts are discovered; no counts or timeouts are configured |
| point/group/core | `WINDOW_BASIS` | raw logic [1:0], validated before enum conversion | `BW_NS` (default) or `BW_CYCLE`; fixed before startup |
| point/group/core | `WINDOW_WIDTH` | raw unsigned logic [63:0] integer ns or cycles | Required, 1..40,000 ns or 1..80,000 cycles according to basis |
| point/group/core | `UPDATE_STRIDE` | raw unsigned logic [63:0] integer ns or cycles | Omitted: effective W; explicit must be known `0<S<=W`; uses the same basis as W |
| point | `POINT_ID` | string | Default `__BW_AUTO__`; otherwise nonempty, unique exact ID |
| point/recorder | `FIXED_BYTES` | four-state 64-bit parameter, bytes/transfer | Default 0 (legal zero-byte transfers); fixed mode requires known value at most 2^32−1 |

Parameter defaults directly express `UPDATE_STRIDE=WINDOW_WIDTH` and Q=10.
Explicit zero, unknown or out-of-range values remain configuration errors;
there is no reserved integer value that silently becomes an omission.
`CLOCK_CONTEXT` is removed: points, type binds and groups no longer declare or
check a clock label, and no clock-consistency probing replaces it. A shared
sampling clock remains a documented usage prerequisite of hierarchical
aggregation; asynchronous aggregation stays out of scope.

The selected protocol determines whether a transfer occurred (see below). The recorder samples control
at the actual positive edge, creates one normalized record per edge, including
idle/reset/unknown states, and supplies the identical record to the local core.
Known reset excludes a transfer. Unknown reset/control marks event and byte
incompleteness; it does not invent zero traffic. Known own reset clears local
statistics, and release restarts window coverage as described below.

## Normalized component boundary

`bw_point_recorder` receives the public `scope_id`, emits `bw_mon_pkg::bw_record_t record` and toggles
`record_toggle` once after each sampled record. `bw_stats_core` accepts the same
ports plus `scope_id` and the window parameters. This component contract is shared
with future group collectors; local counting does not require a global queue.

| Record field | Meaning |
| --- | --- |
| `timestamp_ticks` | Original integer sampling time |
| `edge_index` | Local actual-edge index, unsigned 64-bit |
| `record_seq` | Monotonic source record sequence, unsigned 64-bit; distinct from time/cycle semantics |
| `source_epoch` | Source generation, unsigned 64-bit (initially 0) |
| `byte_inc`, `event_inc` | Known raw increments, unsigned 64-bit |
| `bytes_complete`, `events_complete` | Independent completeness bits |
| `reset_n` | Four-state reset for this edge, including same-time asynchronous reset priority |
| `reset_points` | Number of observed points known in reset on this edge |

The core has a single run-to-completion `dispatch` owner. A frame first supplies
actual sampling-edge metadata. Either a timer action or a frame action publishes
due windows before the frame accounts its new transfer. Thus the right endpoint
is excluded regardless of timer/frame ordering.
The initial public snapshot has zero coverage, invalid denominator and sequence 0;
it is not a published window. In ns mode, planned publications begin at start+S;
cycle mode begins after S complete actual cycles as described below. No extra
publication is inserted when W is first reached if W is not divisible by S.

## Public observation-point scalars

These fields live directly at `bw_point_mon`, independently of private module
layout. `clk`, `reset_n`, and `valid` are also directly visible at that scope.

| Fields | Type / interpretation |
| --- | --- |
| `scope_id`, `monitor_path`, `scope_kind` | Identity string, actual hierarchy string, `BW_POINT` |
| `stats_epoch`, `result_seq` | unsigned 64-bit statistics generation and newly published result sequence |
| `total_bytes`, `total_events` | unsigned 64-bit known cumulative bytes and transfers |
| `window_start_ticks`, `window_end_ticks`, `coverage_ticks` | unsigned 64-bit half-open physical interval and duration |
| `window_start_cycle`, `window_end_cycle`, `coverage_cycles` | unsigned 64-bit half-open actual-edge interval and complete-cycle count in cycle mode; zero in ns mode |
| `window_bytes`, `window_events` | unsigned 64-bit known increments in the exact half-open window |
| `bandwidth_gbps`, `bytes_per_cycle` | real decimal GB/s; latter reserved at zero for ns mode |
| `window_warmup`, `window_full` | Coverage status; independent of byte completeness |
| `bytes_complete`, `events_complete` | Every contribution in this window is known for the corresponding quantity |
| `denominator_valid` | The covered physical duration is positive |
| `window_valid` | Convenience conjunction: full, bytes complete, denominator valid |
| `member_reset_coverage` | At least one known point-reset sample or physical reset interval overlaps the window |
| `raw_record` | Identical normalized record used by the local core, for tracing input evidence |
| `raw_control`, `control_toggle` | Timestamped original-point reset status and its notification; separate from sampling frames |
| `accepted_record_seq` | Latest raw source frame accepted or handled during own reset; transport receipt, independent of window-result sequence |

The ns window at T is `[max(start,T−W),T)`. Events at the left endpoint count;
events at the right endpoint first appear in later windows. During warmup the
bandwidth denominator is actual coverage. Bandwidth is bytes/ticks×1,000,000,
using integer time differences before conversion to real. One B/ns is one GB/s.
Without clocks, timers keep publishing and history naturally expires to zero.
Rolling exact counters and a reclaimable history queue avoid rescanning the whole
window on every publication. There is no user queue-depth configuration.

## Local-cycle windows and clock changes

Select `.WINDOW_BASIS(bw_mon_pkg::BW_CYCLE)` with integer cycle W and S. The
first eligible actual sampling edge anchors cycle coverage; ready time does not
invent a clock edge. The recorder's first edge index is 1, and at that edge the
public result remains the zero-coverage sequence-0 snapshot. At edge `1+S`, the
first scheduled result covers the S completed cycles. Thereafter only actual
edges advance the update schedule. W and S are independent: W=5/S=3 publishes
after 3, 6, 9, ... completed cycles, with the first full result after 6 cycles.

At actual edge k, a full window is `[k−W,k)`; the corresponding physical interval
is `[t(k−W),t(k))`. The left edge's transfer counts and the new transfer at k is
reserved for later results. Warmup clamps the left edge to the first observed
sampling edge and divides by the actual covered cycles/time. `bytes_per_cycle`
is `window_bytes / coverage_cycles`; decimal `bandwidth_gbps` uses the positive
integer timestamp difference before conversion to real. No configured fixed
frequency replaces that measured duration. S=W produces adjacent disjoint
windows with the same endpoint rule.

A stopped clock leaves the cycle result's sequence, endpoints, quality, bytes
and bandwidth unchanged. That held result is the old snapshot. Upon the next
actual edge, the elapsed physical time includes the pause if it lies inside the
completed-cycle window, so GB/s can decrease while B/cycle stays the same. Ns
windows continue on their physical-time schedule and expire to zero during the
same stop. Every normalized record keeps distinct record and actual-edge
indices; a skipped/duplicated edge is a fatal `EDGE_SEQUENCE` error, with expected
and received indices. Cycle boundary times include idle edges and are reclaimed
once older than the maximum retained cycle window.

## Fatal diagnostics and tests

Core errors print `BW_CORE_ERROR code=... scope=... time_ticks=...` with relevant
expected/received counts, identities or arithmetic operands and terminate using
`$fatal`. Current codes cover empty/duplicate identities, bad window/byte/count
configuration, missing setup/incomplete startup, frozen registration/configuration, out-of-order
record time/sequence, actual-edge sequence and exact unsigned arithmetic overflow. Counters widen before
checking addition/multiplication; they never silently wrap or clamp.

Run `make test` or `python3 tests/run.py ns_bind ns_stride`. The runner compiles
and executes actual VCS simulations, keeps compilation and simulation logs under
`.build/tests/<top>/`, and uses `tests/cases.json` to name success/fatal cases.
This VCS version can return shell status zero for `$fatal`; expected-error tests
therefore require the terminal `Fatal:` diagnostic and precise error code, and
reject a test-continuation marker. Success cases require `TB_PASS`.

The real-number assertion tolerance is 1e−10 GB/s for the small hand-calculated
vectors, only to cover binary floating-point evaluation. All bytes, events,
identities, integer times, sequence values and quality flags compare exactly.
This numerical tolerance is separate from the cfg performance tolerance.

| Test | Independent expectation / contract |
| --- | --- |
| `ns_bind` | One type bind to two real target instances; default IDs; transfers at 1, 2.5 and 10 ns of 64 B; `[0,10)`=128 B/12.8 GB/s, `[1,11)`=192 B/19.2 GB/s, `[2,12)`=128 B/12.8 GB/s; empty point stays independent; stopped clock eventually zero |
| `ns_stride` | Explicit identity; 8 B events at 0.25 and 2.75 ns; W=10/S=3, T=3 warmup=16 B/3 ns, first full publication T=12 with `[2,12)`=8 B/10 ns; no T=10 insertion |
| `startup_*` | Empty/duplicate ID, illegal W/S, positive-time registration and repeated configuration terminate with precise diagnostics |
| `auto_*` | Automatic bind discovery with different actual counts, finite t=0 scheduling, prepared reset/hint/report snapshots before one ready, coarse-time lifecycle checks, real group topology errors and early finish |
| `byte_config_error` | Per-transfer byte count above 2^32−1 terminates |
| `cycle_window` | Independent .25/.75/1.25/2.25/12.25/12.75/13.25/13.75 ns edge table; W2/S1; sub-ns warmup, frequency change, stopped-clock hold and resume; actual-time GB/s and B/cycle; ns history expires during the same stop |
| `cycle_stride` | 2 GHz known-valid event table with W5/S3 and W3/S3; no off-schedule first full result; left/right events and S=W adjacent windows |
| `cycle_config`, `startup_*_limit`, `startup_cycle_bad_stride` | 80,000-cycle width accepted as a configuration; excess ns/cycle widths and illegal cycle stride terminate; this is not a scale/history acceptance run |
| `cycle_edge_error` | Core normalized-record boundary rejects a skipped actual-edge index even with contiguous record sequence |

Initial validation: 11/11 contract cases passed on 2026-10-24 with
VCS W-2024.09-SP1_Full64, GNU g++ and Python 3.6.8 on Linux x86-64.

Cycle-window validation on the same tools: 18/18 cases passed, including the
original ns/startup regression and seven new cycle/configuration/error cases.
Reproduce with `python3 tests/run.py`; targeted cycle behavior uses
`python3 tests/run.py cycle_window cycle_stride cycle_config cycle_edge_error`.
This component/integration validation does not claim the separate scale matrix
or real monitor waveform/human acceptance has been completed.

## Protocols, adapters and coherent samples

Select the accounting convention once per point:

| Point/recorder parameter | Type | Meaning |
| --- | --- | --- |
| `PROTOCOL` | `bw_protocol_t` | Default `BW_VALID_ONLY`; also `BW_VALID_READY` and `BW_CREDIT`; unsupported/unknown value is fatal |
| `DYNAMIC_BYTES` | raw logic [1:0], known0/1 | Default 0: count `FIXED_BYTES` on each transfer. Set 1: use that transfer's decoded `size_bytes` and `size_known` |

| Raw input | Type / default | Role |
| --- | --- | --- |
| `valid` | logic, default 0 | Transfer control for valid-only and valid-ready |
| `ready` | logic, default 0 | Acceptance control for valid-ready |
| `flitv` | logic, default 0 | Actual send control for credit protocol |
| `lcrdv` | logic, default 0 | Credit return evidence, independent of counted sends |
| `size_bytes` | logic [63:0], default X | Current transfer's already decoded accounted bytes, 0..2^32−1 |
| `size_known` | logic, default 0 | Adapter explicitly proves its byte decode known by driving 1; raw `size_bytes` must also contain no X/Z |

`BW_VALID_ONLY` uses `valid`; `BW_VALID_READY` uses the four-state expression
`valid & ready`; `BW_CREDIT` uses `flitv` alone. Thus valid=0 or ready=0 can prove
no handshake even when the other signal is unknown. Unknown control that cannot
prove activity/idle produces an observation gap. Flitv=1 counts even with lcrdv=0
or X; credit diagnosis does not grant permission or erase known transfers.

A definite transfer always adds one event, even if it has zero bytes or an
unknown size. An unknown size adds zero *known* bytes and sets
`bytes_complete=0`, while `events_complete` remains true. A control gap makes
both completeness flags false. A definite idle ignores unused unknown size
fields. Known contributions remain in cumulative/window values with incomplete
flags; those flags recover when the unknown positions expire from the window.
Fixed mode ignores dynamic size/knownness altogether. A trusted dynamic decode
above 2^32−1 is a `TRANSFER_BYTES` core error with Point ID and sampled byte value.

The DUT-specific wrapper owns size encoding conversion. Do not connect the whole
transaction's byte count on every beat. An executable wrapper example is
`tests/tb_adapter_decode.sv`: its interface encoding maps the current beat to
16/32/64/128 B, propagates unknown decode separately, and retains the original
`size_code` at the wrapper's scope. The generic monitor receives only decoded
bytes; it does not silently interpret AXI, CHI or other DUT encodings.

All raw fields are copied together at the actual positive sampling edge, in one
nonblocking-free active-region action. The normalized record is then built from
that immutable snapshot, and its notification toggles in NBA. A synchronous DUT
may update its next control and size with nonblocking assignments at the same
edge: the monitor consistently observes their pre-NBA transfer. Drive TB stimuli
before the edge; competing blocking DUT/TB updates at the very same edge are a
SystemVerilog race and are not a supported sampling contract.

The exact snapshot is `sampled_view` (`bw_sample_t`), retained alongside
`raw_record`. Direct public four-state scalar aliases are `sampled_reset_n`,
`sampled_valid`, `sampled_ready`, `sampled_flitv`, `sampled_lcrdv`,
`sampled_size_bytes` and `sampled_size_known`. The live input ports remain visible
too. `protocol` and `dynamic_bytes` expose the selected convention. A credit point
also exposes the independent credit capability, enable, trust and ledger states
described below. These diagnostic states never change accounting quality.

Additional contract cases:

| Test | Independent expectation |
| --- | --- |
| `protocol_recording` | All three protocols, zero bytes, unused size X, definite event/unknown size, unknown control and independent byte/event quality; known windows recover after unknown positions expire |
| `subns_vectors` | Spec T5-E2 raw event table translated +1 ns so relative zero is a legal edge after ready; relative T=10/11/12/20/22 gives exactly 320/384/384/256/256 B and 32/38.4/38.4/25.6/25.6 GB/s |
| `sample_view` | DUT nonblocking control+size updates preserve matching pre-edge fields; 8 B, idle, 16 B, 2^32−1 B produces exactly 4,294,967,319 known bytes and three events |
| `recorder_edges` | Known reset, unknown reset, definite fixed-byte handshake and idle each publish their own record with original timestamp and monotonically increasing sequence |
| `adapter_decode` | Two encoded 32-byte beats count 64 B; unknown decode preserves event, unused unknown decode during idle remains complete |
| `dynamic_size_error`, `protocol_config_error` | Oversized known transfer or unsupported protocol terminates with the precise core diagnostic |

All integer/quality checks remain exact; real comparisons retain the separately
declared 1e−10 GB/s numeric assertion tolerance.

## Own reset, member reset and no-clock controls

A point's known `reset_n=0` advances its `stats_epoch` once, clears its own
cumulative/window history and returns a zero-coverage snapshot. While held in
reset, actual clock edges still produce complete reset frames with zero transfers;
the core accepts them and advances `accepted_record_seq`. No window is published
while known own reset is held. Release restarts ns scheduling at release+S and
cycle coverage at the first eligible actual edge. A known transfer on the release
edge belongs to the new statistics interval. `result_seq` remains monotonic and
advances only for a publication; clearing a snapshot does not publish a window.
Registration, identity and raw source edge/record sequences stay unchanged.

The recorder also publishes `bw_control_t raw_control` on initial ready and every
observed reset-level change. These controls have no cycle field and never create
sampling frames. `control_toggle` notifies after the control is stable; internal
transport can copy/persist it before the next notification. `record_toggle` and
`raw_record` remain a separate stream. The fields are:

| Control field | Type / meaning |
| --- | --- |
| `timestamp_ticks` | Unsigned 64-bit original physical time in fs |
| `control_seq` | Unsigned 64-bit monotonic per-point control sequence, initially 1; distinct from source records and cycles |
| `source_epoch` | Unsigned 64-bit point-source generation; advances once on a known reset assertion and never rewinds |
| `point_handle` | Unsigned 32-bit registered Point ID handle, obtainable through `point_handle_for_id(id)` |
| `reset_n` | Original four-state observed reset level; X and Z remain unknown |

A source frame carries the current `source_epoch`. Initial known reset at ready
starts epoch 1; initial release starts epoch 0. Reset assertion/release during a
stopped clock changes controls without advancing `raw_record.record_seq` or
`raw_record.edge_index`.

The reusable core keeps own reset separate from member controls:

| Core port | Type / default / contract |
| --- | --- |
| `stats_reset_n` | Four-state logic, default 1; resets only this scope's statistics |
| `member_control`, `member_control_toggle` | `bw_control_t` plus notification, default zero/inactive; original point controls supplied by a collector |
| `accepted_record_seq` | Unsigned 64-bit receipt after each raw frame has been counted or explicitly handled during own reset; never clears on statistics reset |
| `accepted_control_count` | Unsigned 64-bit lifetime receipt count after member-control acceptance; never clears on statistics reset |

Member controls retain known-reset and unknown-reset physical intervals, including
intervals with no sampling edges. A known member reset sets window reset coverage
without invalidating known bytes or clearing history. Unknown reset marks byte and
event observation incomplete for overlapping windows; known contributions remain.
Closed intervals expire exactly at the half-open left boundary. Own reset clears
its statistics history while retaining current member reset states and transport
positions. This is the normalized component seam for collectors; the group tickets
provide the complete topology and transport integration.

An unknown own reset does not assert a known reset or clear its epoch/history.
Ns results include its unknown interval even with no clocks. Cycle results hold
the old published snapshot during a clock stop; after resume, new windows account
for the reset interval in their actual physical coverage. A later complete window
can recover completeness after the interval leaves it.

Protocol controls and dynamic size are captured from the same pre-NBA edge view.
The private reactive coordinators settle module reset changes before processing
queued actions, with own reset before publication. A same-time assertion therefore
suppresses both the old-epoch window and the point's raw transfer, including NBA
assertion drives. Deassertion preserves the original edge-sampled reset: a DUT
sampling reset0 or X before an NBA release does not acquire a fabricated transfer.
Active release before the edge counts normally. Current-edge data remains excluded from a normal window at T. A
later frame at the same T still supplies metadata and receives acceptance; time
alone never suppresses a frame. These coordinators are instantiated internally;
integrators do not drive them.

The global `monitor_start_ticks` equals the published common measurement start T
and is independent of every local statistics origin. The supported duration is
40,000 ns from T, including the endpoint. A subsequent action beyond it terminates with
`SIM_TIME_LIMIT`, including after a local reset near the limit. Internal queues
grow/reclaim automatically; queue-index representation exhaustion reports
`STORAGE_RANGE` with scope and entry count. No user history-depth setting is added.

Reset reproduction uses `python3 tests/run.py reset_rewarm reset_same_time_0
reset_same_time_1 reset_same_time_2 reset_same_time_3 reset_unknown
reset_cycle_unknown reset_initial reset_member_controls member_control_error
member_control_reference_error
reset_deassert_sample reset_time_budget`. The four same-time variants observe every publication change,
not merely final cleared scalars, for both window bases. Other cases independently
check no-edge assertion/release, schedule restart, source/control epochs and
sequences, physical unknown-interval expiry, member/own isolation, duplicate-control/unregistered-source
fatal behavior and immutable global time. Integer/state comparisons are exact;
small real-value assertions retain the separate 1e-10 numerical tolerance.

## Credit ledger and diagnostic trust

The `bw_debug_hints` component consumes the same `sampled_view`, `record` and
`record_toggle` as the recorder/core path, plus live `reset_n` for no-clock reset
notification. It never changes a normalized record or grants/blocks a transfer.
Credit parameters pass from `bw_point_mon` to this component:

| Parameter | Type / default | Meaning and rejection |
| --- | --- | --- |
| `CREDIT_ENABLE` | raw logic [1:0], default0, known0/1 | Request ledger diagnostics; capability remains separate |
| `CREDIT_CAPACITY` | four-state logic [63:0], X | Explicit known capacity required when a credit-protocol ledger is enabled; 0..2^64−1 are legal |
| `CREDIT_INITIAL` | four-state logic [63:0], X | Explicit starting balance, used only when initial knowledge is asserted |
| `CREDIT_INITIAL_KNOWN` | raw logic [1:0], default0, known0/1 | Unknown initial balance stays unknown; if 1, initial value must be known and within capacity |
| `CREDIT_RETURN_TIMING` | `bw_credit_return_t`, `BW_RETURN_NEXT_CYCLE` | Alternative `BW_RETURN_SAME_CYCLE`; unknown/unsupported timing is fatal when enabled |

The package's shared `validate_point_protocol` and `validate_credit_config`
functions run **before point registration**, and component modules reuse them.
Invalid protocol, fixed-byte or enabled credit configuration cannot advertise
`BW_READY`. Fixed byte configuration remains four-state until validation;
X/Z cannot silently become a legal zero-byte amount. Disabled/unsupported credit
configuration does not require unused ledger capacity or initial values.

A trusted pre-edge balance C permits a send only if C is positive, adding this
edge's R only in same-cycle return mode. Each definite `flitv` consumes exactly
one credit, including a zero-byte flit; each `lcrdv` returns one credit. Updated
balance is C+R−S and must remain within [0,capacity]. Permission arithmetic uses
65 bits, and updated balance uses **signed 66-bit** arithmetic, representing
−1 through 2^64 exactly. For example, C=0/S=R=1 loses trust in next-cycle mode;
same-cycle mode permits that send and retains a trusted zero balance.

Unknown send/return, unknown reset, send without credit or range violation loses
trust. The first fault reason remains until a known reset, the numeric balance
becomes X, and the last trusted balance is retained. Later known S/R observations
do not repair the lost ledger. A known reset assertion interrupts diagnostics,
advances the ledger epoch once, and restores the configured seed on release,
including with no sampling edges. If that seed was not known, reset does not
invent a numeric balance. Returning directly from unknown reset to reset_n=1
also cannot prove a new seed. There is no runtime configuration update.

`BW_HINT_CREDIT_ANOMALY` logs Point ID, integer time, source record sequence,
reason, last trusted balance, raw send/return and exact attempted balance. A
credit protocol anomaly continues simulation and preserves every definite flit
and its known bytes; it is separate from a fatal statistics representation
error. It is also separate from any performance conclusion or evidence of demand.

Public scalar fields live directly at the observation point:

| Field | Meaning |
| --- | --- |
| `credit_supported`, `credit_enabled`, `credit_trusted` | Capability, requested enable and current trust, separately |
| `credit_state` | `BW_CREDIT_UNSUPPORTED`, `BW_CREDIT_DISABLED`, `BW_CREDIT_UNKNOWN`, `BW_CREDIT_KNOWN` or `BW_CREDIT_RESET` |
| `credit_capacity`, `credit_initial`, `credit_initial_known`, `credit_return_timing` | Exact configured values and knowledge/timing |
| `credit_balance` | Current logic [63:0] balance; X when unknown/untrusted; while known reset holds it can show configured seed but trust remains false |
| `credit_last_trusted_balance` | Last known logic [63:0] balance; remains X if no known seed ever existed |
| `credit_available_before` | Last checked frame's 65-bit usable credit count, including same-cycle return if selected |
| `credit_attempted_balance` | Last checked frame's signed 66-bit C+R−S, retaining the exact out-of-range attempted value on an anomaly |
| `credit_permission_known`, `credit_send_permitted` | Whether the last frame's permission check was possible and its result; these describe that pre-edge check, not future permission |
| `credit_shortage_known`, `credit_shortage` | Whether current usable-credit shortage can be decided and its result; same-cycle mode includes live return availability, next-cycle mode uses stored balance; does not prove pending demand |
| `credit_anomaly`, `credit_reason` | First trust-loss latch and reason; cleared by known reset |
| `credit_anomaly_count` | Unsigned 64-bit cumulative trust-loss count, preserved across resets; initial unknown state alone is not an anomaly |
| `credit_epoch`, `credit_result_seq` | Unsigned 64-bit reset generation and monotonic diagnostic update sequence |
| `credit_update_ticks`, `credit_record_seq` | Last diagnostic update's integer fs time and last consumed source record sequence; a reset notification does not invent a record/edge |

The last-frame permission/attempt fields become unknown when a later frame cannot
be checked. The original fault remains in its log and latched reason. Current
shortage is a usable-credit predicate, qualified by trust and live reset,
independently from the last frame's permission evidence. In same-cycle mode live
return availability can change this predicate without changing stored balance. Duration thresholds and long-condition hints are configured independently below.

Additional independently expected VCS cases:

| Test | Contract evidence |
| --- | --- |
| `credit_timing` | C=0/S=R=1 both timings; disabled and unsupported states; identical 128 B window accounting with enabled/disabled/anomalous diagnostics |
| `credit_ledger` | Literal balances 2→1→0→1→1; unknown return loses trust while definite bytes count; no-clock reset recovers seed; capacity overflow retains attempted 3; unknown send remains a genuine observation gap |
| `credit_boundaries` | Exact 2^64 permission intermediate and attempted balance; legal zero capacity; zero-byte flits still consume one credit; exact attempted −1; unknown initial value remains unknown |
| `credit_reset_unknown` | No-clock unknown reset breaks trust; direct return to 1 does not repair it; a subsequent known reset restores seed without inventing record sequences |
| `credit_config_error`, `credit_initial_error`, `credit_return_error`, `fixed_unknown_config` | Missing capacity, initial balance outside capacity, invalid timing and unknown fixed bytes terminate before any `BW_READY` |

## Sustained backpressure and credit-shortage hints

Each hint has its own explicit configuration, independent of window basis/W/S:

| Point/debug-hints parameter | Type / default | Meaning |
| --- | --- | --- |
| `BACKPRESSURE_ENABLE` | raw logic [1:0], default0, known0/1 | Request sustained valid-ready backpressure hints |
| `BACKPRESSURE_BASIS` | four-state logic [1:0], X | Required `BW_NS` or `BW_CYCLE` when enabled and supported |
| `BACKPRESSURE_THRESHOLD` | four-state logic [63:0], X | Required positive integer ns or complete local cycles |
| `SHORTAGE_ENABLE` | raw logic [1:0], default0, known0/1 | Request sustained trusted-credit-shortage hints |
| `SHORTAGE_BASIS` | four-state logic [1:0], X | Required `BW_NS` or `BW_CYCLE` when enabled and supported |
| `SHORTAGE_THRESHOLD` | four-state logic [63:0], X | Required positive integer ns or complete local cycles |

`validate_hint_config` runs before point registration. Missing, unknown, zero or
invalid settings terminate with `HINT_CONFIG`; ns thresholds whose tick count
cannot be represented terminate with checked `INTEGER_OVERFLOW`. No threshold or
basis is guessed from window configuration. Disabled/unsupported hints need no
unused threshold and create no duration scheduler. A supported enabled shortage
hint with an unavailable/disabled ledger remains untrusted; it cannot invent a
shortage interval.

Backpressure uses the live four-state `valid & ~ready` condition. For example,
valid=0 proves no backpressure even if ready is unknown. Credit shortage follows
D4's usable-credit rule, while stored credit C changes only on actual records:

| Trusted stored C | Return timing / live R | Current shortage |
| --- | --- | --- |
| C>0 | Either timing, including unknown R | Known false: at least one credit is available |
| C=0 | Next-cycle, any live R | Known true until a sampled update changes C |
| C=0 | Same-cycle, R=0 | Known true |
| C=0 | Same-cycle, R=1 | Known false: this return is usable |
| C=0 | Same-cycle, R=X/Z | Unknown |
| Untrusted C or reset | Either | Unknown / reset interruption |

Thus a permitted C=0/S=R=1 same-cycle stream does not accumulate a sustained
shortage hint. Live same-cycle R can start/release/interrupt a hint during a
stopped clock, but it never increments the ledger without a sampling record.
Unknown send activity does not determine current credit availability or pending
demand. When an actual record has unknown S/R, it still loses ledger trust as
documented above. Neither hint condition establishes a performance failure.

For ns mode, a raw condition becoming known true starts an interval at its actual
integer time. A dedicated threshold timer still triggers with no sampling clocks.
Release, unknown and reset changes close or interrupt the interval at the live
change time. Cycle mode counts only complete intervals between actual local clock
edges during which the raw condition continuously remained known true. A
mid-cycle assertion waits for the next edge anchor; the following edge completes
its first counted cycle. Stopped clocks add no cycles or new cycle results.
Resuming after a long stop closes the one actual local cycle ending at that edge.

At a same-time edge and release/unknown/reset, the complete prior cycle is settled
before closure. At a threshold-equal change, the preceding half-open trusted
interval retains its hit. Raw changes at T contribute no later unknown/reset time
to that interval. The implementation keeps durable action counts, captures actual
clock metadata before recorder ReNBA publication, and uses a private Reactive
coordinator. A credit-shortage condition starting after a finalized same-time
ledger frame can attach to the already observed clock boundary, without an extra
cycle of hint latency. Users do not advance this machinery.

The first threshold crossing emits one `BW_HINT_HIT`; ending an interval emits
one `BW_HINT_END`, including intervals shorter than threshold. End reasons are
`RELEASED`, `UNKNOWN`, `RESET` and `TRUNCATED` (observation ended while active).
Unknown/reset splits intervals, so evidence cannot join across the gap. An active
interval is settled once at simulation end, preserving only cycles already
completed. Logs include scope, hint kind, interval epoch/ID, result sequence,
start/trigger/end times and exact observed tick/cycle durations. Hint counters and
logs remain separate from all performance conclusions.

Fields below exist directly at `bw_point_mon`, with either `backpressure_` or
`shortage_` prefix. Their packed `backpressure_result`/`shortage_result` values are
also available, but scalar aliases are the stable waveform surface.

| Suffix | Meaning |
| --- | --- |
| `supported`, `enabled`, `trusted` | Interface capability, requested enable and current known condition/reset |
| `active`, `hit` | Current interval active; current or most recently ended interval reached threshold |
| `basis`, `threshold` | Exact independently configured basis and threshold |
| `epoch`, `interval_epoch`, `interval_id` | Current known-reset generation, this result's original generation, and monotonic interval identity |
| `result_seq`, `update_ticks` | Monotonic newly processed hint result and its integer fs update time |
| `start_ticks`, `trigger_ticks`, `end_ticks` | Actual condition start, first threshold crossing and final half-open endpoint; zero trigger means no hit |
| `duration_ticks`, `observed_through_ticks` | Exact physical duration as of the indicated observation boundary |
| `cycle_anchor_valid`, `start_cycle`, `end_cycle`, `duration_cycles` | Complete-cycle anchor, actual local edge indices and completed-cycle duration |
| `end_reason` | `BW_HINT_NOT_ENDED`, `BW_HINT_RELEASED`, `BW_HINT_UNKNOWN`, `BW_HINT_RESET`, `BW_HINT_TRUNCATED` |
| `hit_count`, `interval_count` | Unsigned 64-bit lifetime count of first hits and closed intervals, never mixed with byte/event or performance counters |

An active duration snapshot updates at raw changes, actual edges and threshold
publication. After a hit with no further events, its sequence and
`observed_through_ticks` identify the held snapshot; final closure calculates the
entire actual interval. Holding that snapshot does not repeat a hit or turn it
into new evidence. The current reset generation may advance after a summary;
`interval_epoch` keeps that summary's original identity.

Additional independent tests:

| Test | Evidence |
| --- | --- |
| `hint_ns` | No-clock start/hit/release, unknown/reset gaps, no joined evidence, exact final 2.5 ns truncated interval |
| `hint_equal` | Separate threshold-equal release, unknown and reset retain one hit and exactly 2 ns of prior trusted duration |
| `hint_cycle` | First edge anchors; stopped clock holds sequence/count; same-edge release closes two completed cycles; mid-cycle/unknown/reset split; capability and enable separate |
| `hint_shortage` | NEXT mode retains known stored-credit availability off-edge; sampled unknown R/S interrupts trust, real return ends shortage, and definite bytes still match disabled point |
| `hint_credit_cycle` | Same-edge return closes a completed shortage cycle; late finalized ledger start reuses current actual edge anchor without extra-cycle delay |
| `hint_same_cycle_stream` | Exact C=0/S=R=1 stream has no ns or cycle shortage interval, retains zero stored balance and counts all five 8-byte sends |
| `hint_same_cycle_live` | No-clock R0/R1/RX/RZ changes implement the usable-credit truth table; C>0 remains known no-shortage even with unknown R; no phantom ledger/event updates |
| `hint_same_cycle_cycle_live` | Live R releases/interrupts cycle evidence while stopped; gaps require fresh full cycles; current availability stays separate from the historical sampled permission |
| `hint_cycle_truncation` | Observation-end summary retains one completed cycle over a long stopped clock and cannot fake a hit from physical time |
| `hint_accounting` | Enabled ns hint fires before any cycle-window sample, then both enabled/disabled points count the same 24 B/three events and 8 GB/s full cycle window |
| `hint_reset_release` | A frame sampled while reset was held cannot debit credit when reset releases later at the same T; the first real send and subsequent return create exactly one complete shortage cycle |
| `hint_time_budget`, `hint_final_budget` | With a stopped clock and cycle windows, both a future ns timer and final settlement still enforce the immutable 40 us budget; rejected actions cannot publish a new hint interval |
| `hint_missing_basis`, `hint_missing_threshold`, `hint_zero_threshold`, `hint_bad_basis`, `hint_time_overflow`, `hint_unknown_protocol` | Invalid enabled configuration fails before `BW_READY`, including unknown defaults and exact tick overflow |

The runner's optional `expect_log` patterns test final hint logs through the
public logging boundary after `$finish`; success still requires `TB_PASS` and no
fatal diagnostic. All interval, state, sequence and numeric duration comparisons
are exact integers/four-state values.

Reset/credit integration validation: **46/46 contract cases passed** on
2026-10-24 with VCS W-2024.09-SP1_Full64 and Python 3.6.8, including thirteen new
reset/control cases. The DUT-like NBA-deassert fixture verifies that a sampled
known reset0 or unknown reset cannot become a transfer after NBA release; its
Active-release case still counts. The credit-ledger stimulus now explicitly uses
integer-fs testbench time and checks actual raw timestamps against its event table.

## Aggregation and startup

Instantiate one `bw_group_mon` per Group ID and use the shared configuration
entry points. Each real group instance declares its Group ID. Points register only
their own identity/configuration; they need no Group ID or data wiring to a group.
The setup discovers counts and seals all t=0 member rules automatically:

```systemverilog
bw_mon_setup setup();
bw_group_mon #(.GROUP_ID("noc1"), .WINDOW_WIDTH(2), .UPDATE_STRIDE(1)) noc1
  (.clk(clk), .reset_n(group_statistics_reset_n));
initial begin
  add_point_member("noc1", "tb.noc1", BW_PREFIX);
  add_point_member("noc1", "tb.noc1.p0"); // duplicate hit counts once
  wait(monitor_ready);
  // Drive traffic on a sampling edge strictly after measurement_start_ticks.
end
```

The three points in this example must already use the common group clock/window
configuration; the third may remain ungrouped. Point IDs and Group IDs have
separate namespaces. `BW_EXACT` is the default match kind. `BW_PREFIX` matches a
complete dot-delimited hierarchy prefix, including that prefix itself; `noc1`
cannot match `noc10`. A prefix ending with a dot already supplies the delimiter.
No matches or an empty group is fatal. The direct-member count is derived after
deduplication; a subgroup counts as one direct member.
Groups can also contain explicitly named subgroups, alone or mixed with points.
Use `add_group_member(parent, child)` for an exact Group ID; a Point ID with the
same text remains a different source. The generic entry
`add_member(parent, BW_POINT|BW_GROUP, id, match)` makes the kind explicit and
validates its four-state 2-bit value before narrowing. Group prefixes are rejected.
Duplicate rules selecting the same typed direct source count once; overlapping
recursive paths through different direct members are errors.

| Entry/configuration | Type / default | Contract |
| --- | --- | --- |
| `bw_mon_setup` | one parameterless instance | Discovers all points and groups, including ungrouped points and intermediate groups |
| group `GROUP_ID` | string, required | Nonempty unique group owner; equal Point ID text is legal |
| group clock/window parameters | same basis/W/S as points | Every direct member must share basis, width and stride; a common actual sampling clock is a usage prerequisite |
| `add_point_member(group,id,match)` | exact Point ID or segment prefix | Legal only at actual t=0; target may register later in that time slot |
| `add_group_member(group,child)` | exact Group ID | Legal only at actual t=0; subgroup may register later in that time slot |
| `add_member(group,kind,id,match)` | explicit `BW_POINT` / `BW_GROUP`; match defaults `BW_EXACT` | Unknown/invalid kind, or group prefix, is fatal |

Actual counts retain the 16,384-point and 4,096-group limits. Registration,
configuration, reference, owner, window, edge/fanout and capacity checks finish
before ready. A tri-color traversal rejects cycles, computes recursive point sets
and checks at most eight nested group levels. Each direct member must contribute
a disjoint recursive point set; point/subgroup, sibling and diamond overlaps fail
with the conflicting Point ID and both typed paths. No path is automatically
removed. Reuse between independent scopes is allowed. Up to 65,536 deduplicated
direct edges and sixteen direct parents per point or group source are checked; their actual maximum-scale execution is a later acceptance
step. A member rule without a real owning group, an invalid reference or an empty
group fails during sealing, with the object and actual startup state in the log.
All finite t=0 scheduling chains participate; any positive-time configuration
call is late even if it executes before the setup's seal action in that slot.

Compile the package first, add `+incdir+rtl`, and enable VCS deferred-assertion
support with `-assert svaext`. The registry/transport headers are part of
`bw_mon_pkg`; they are not separate compilation units. `tests/run.py` supplies
these options and hashes included RTL headers recursively as well as compilation
units, so editing a header invalidates the compile cache.

## Group results and same-time consumption

A group exposes the same window identity/epoch/sequence, raw totals, endpoints,
coverage, GB/s/B-cycle and independent quality scalars as a point, directly at
its public scope. `scope_kind` is `BW_GROUP`. Additional fields are
`direct_member_count`, `recursive_point_count`, `raw_record`, `raw_control`,
`control_result_seq`, `accepted_record_seq` and `accepted_control_count`.
`raw_record` is the current original-time group increment, independently of
whether the group's own statistics are in reset. Its source epoch remains
independent of statistics reset. Actual member reset coverage is summed;
group-only reset never creates an actual point reset.

The package persists one source frame before advancing its direct groups' durable
notification counters. Each direct consumer has package-owned frame/control
acknowledgement positions. A group reads only direct raw increments and sums
known bytes/events with checked unsigned 64-bit arithmetic, preserving the
original timestamp and actual edge index. Byte and event completeness propagate
separately. No child bandwidth or cumulative statistic is an input. Before input
acknowledgement, the group output is durable and its own core has accepted or
explicitly handled the frame during reset. Every active direct consumer must acknowledge, or have its responsibility explicitly cancelled by quarantine, before a source record is released. The frozen dependency graph is retained separately from active subscriptions. Ungrouped sources still validate publication
order but require no retained communication backlog.

The group captures expected actual edges without blocking. Missing/duplicate/
out-of-order/wrong-time data is distinct from known idle, zero-byte activity,
unknown protocol/size and known reset. A pending frame or older control prefix
holds a logical publication watermark: a window including unreceived data cannot
appear as complete zero. Upon complete delivery, the published window retains its
original scheduled endpoint. The collector merges controls and frames in original
timestamp order; same-time controls precede the frame. Pending source progress is
propagated through direct parent groups at every hierarchy level.

Independent native actual-edge observers establish group obligations even if capture fails. Writable completion audits wait on explicit posted grants and durable producer certificates through the frozen DAG. Each group records capture, held input, output publication, local core/reset receipt and input ACK separately. Controls, captured resets and due core timer actions also require receipts. No physical missing-record timeout, fixed quiet-round count, next-edge wait or queue-empty certificate exists. A stopped shared clock creates no new expected edges.
Ns windows continue when caught up; cycle snapshots hold. Known point reset keeps
ancestor history until natural expiry and supplies timestamped reset coverage even
without clocks. Group statistics reset clears only its core while collection,
publication and acknowledgements continue.

The controlled package seam provides `peek_member_frame/control`,
`acknowledge_member_frame/control`, logical retained-record counts and
`acknowledged_frame_seq` for component tests/diagnostics. Ordinary integration
uses none of those calls. `registered_scope_count(kind)` and
`registered_scope_id(kind,index)` provide immutable typed identities after ready
for reporting; accessing them before ready is an error.

Core diagnostics include `GROUP_COUNT`, `GROUP_REFERENCE`, `GROUP_DEFINITION`,
`DUPLICATE_OWNER`, `EMPTY_GROUP`, `MEMBER_COUNT`, `MEMBER_RULE`, `GROUP_CONTEXT`,
`GROUP_CYCLE`, `GROUP_OVERLAP`, `GROUP_DEPTH`,
`TOPOLOGY_LIMIT`, `CONFIG_FROZEN`, `RECORD_SEQUENCE`, `EDGE_SEQUENCE`,
`RECORD_TIME`, `FRAME_ALIGNMENT`, `GROUP_COMPLETION`,
`CONTROL_SEQUENCE`, `CONTROL_ORIGIN`, `ACK_SEQUENCE` and unexpected premature
release. Logs identify the group/source and expected/received time, edge or
sequence as appropriate. Runtime errors warn and quarantine the typed owner and its dependent ancestors. Failed consumers cancel only their own inbound obligations; reliable children and siblings continue. Quarantine is sticky across reset. Startup/configuration failures remain fatal. Observation incompleteness continues with known contributions and explicit quality.

Reproduction uses `python3 tests/run.py group_basic group_matching group_delayed
transport_retention group_metadata_order group_metadata_reactive
group_control_barrier group_cycle_quality group_reset_quality group_wide` plus
the `group_fault_*` and `group_config_*` cases in `tests/cases.json`. The wide
case independently checks 8,589,934,590 B per edge; its real tolerance is 1e-5
GB/s (about 1.2e-15 relative), while integer values remain exact and small-vector
real checks use 1e-10. These are numeric calculation tolerances, not performance
acceptance tolerances. The original single-level cases are supplemented by the
hierarchy cases below; FSDB/human and complete scale execution remain separate
acceptance work.

Transport resource accounting is separate from scope statistics history. Logical
packed payload sizes are 451 bits per raw frame, 225 per point control and 289 per
transport control envelope, plus simulator representation/container overhead.
State includes retained source backlogs, two acknowledgement positions per direct
edge, current expected edges/collector frames, per-origin control validation, rules,
source descriptors and a 16,384-bit recursive-point mask per group (8 MiB at 4,096
groups). Retention follows actual consumer lag and cannot be equated to the whole
80,000-cycle scene. Statistics/phase/episode histories are additional independent
state. Actual peak memory and the complete scale/history matrix remain later
acceptance work; no user queue-depth or fixed memory-cap option is introduced.

Hint action producers reuse the same `check_monitor_time` and
`check_queue_growth` guards as the recorder/core. Every queue push checks its
representable entry count; a rejected fatal time/storage action cannot publish a
final hint interval. No user queue-depth or history-capacity setting is added.

`core_failure_seen` is a shared terminal-core-error latch, set before
`core_error` calls `$fatal`, and never cleared by local resets. Performance
FAIL/WARNING and credit-protocol anomalies do not set it. VCS can continue a
final block after `$fatal`; finalizers therefore check this latch before output
and after checked arithmetic. The pure
`monitor_time_supported(bw_u64_t at_ticks)` predicate permits an explicit branch
before final settlement, while `check_monitor_time` supplies the fatal diagnostic.
The budget regression also verifies the failure latch is visible to other final
blocks before they emit results.

## Traffic episodes and e2e results

Episode analysis uses the shared `bw_stats_core` behind ordinary point/group
input paths. The raw logic [1:0] `EPISODE_ENABLE` policy accepts known0/1. Set `EPISODE_ENABLE=1` and optionally configure
`SILENCE_THRESHOLD=Q`. Q is a positive known unsigned 64-bit integer in the
selected `WINDOW_BASIS` (ns or local cycles). An omitted Q defaults to 10 in
the selected basis (10 ns or ten local cycles) when episode analysis is enabled.
`EPISODE_ENABLE=0` is the default window-only mode; Q is then unused and not
validated. An enabled zero/unknown/unrepresentable Q is `EPISODE_CONFIG` before
the point registers and before ready; illegal effective values never fall back
to the default. An unrepresentable ns-to-tick conversion is a core arithmetic
error. These are startup parameters and cannot be changed during simulation.

A definite transfer starts or extends an episode, including a zero-byte
transfer. The measured interval begins at its first actual sampling edge and
ends at the actual edge immediately after its last transfer. This tail edge
must really occur: a stopped clock cannot supply an estimated period. Internal
idle cycles count in the duration; the later Q-length confirmation wait does
not. Ns silence advances with physical time after the tail is known and has an
independent timer even when Q is not aligned with the window stride. Cycle
silence advances only at actual edges. A transfer exactly at the quiet deadline
belongs to a new episode after the old result completes.

Unknown event observations interrupt quiet evidence. Recovery starts a fresh
quiet interval; two sides of a gap are never joined. An unknown size on a
definite transfer preserves its event and both transfer-time boundaries but
makes bytes incomplete. A gap before the first known transfer can make the
start ambiguous; a gap after the last known transfer can make the end ambiguous.
A later known transfer can establish the last boundary again, while byte/event
incompleteness remains sticky for that episode. A complete quiet separator
allows the next episode to be judged independently. Window recovery does not
repair an older episode. Actual-point reset controls carry the same quality
rules through a stopped clock. Known member reset is separate coverage metadata
and does not reset an ancestor's episode or discard its known bytes.

Own known reset interrupts the current episode before clearing that scope's
statistics; the interrupted result carries the old statistics epoch. A reset
at a Q deadline takes priority over normal completion and any same-time transfer.
Observation end emits a truncated result if an episode remains pending. Neither
interruption nor truncation is a valid complete e2e. Core errors remain fatal;
the shared `core_failure_seen` latch prevents final-result output after a core
failure, including VCS final-block paths where `$fatal` can return to its caller.
An unsupported final observation time is rejected before settlement.

The following ordinary scalars are directly visible at each public point:

| Fields | Meaning |
| --- | --- |
| `episode_active`, `episode_status` | Current activity and `BW_EPISODE_NONE`, `ACTIVE`, `COMPLETE`, `RESET_INTERRUPTED` or `TRUNCATED` status |
| `episode_id`, `episode_result_seq` | Lifetime monotonic episode identity and final-result sequence; neither is a window sequence |
| `episode_first_ticks`, `episode_last_ticks`, `episode_tail_ticks` | First/last definite transfer and actual tail-edge timestamps |
| `episode_first_cycle`, `episode_last_cycle`, `episode_tail_cycle` | Corresponding actual source edge indices; controls do not advance them |
| `episode_confirmation_ticks` | Normal quiet confirmation, own-reset interruption or observation-end time |
| `episode_first_known`, `episode_last_known`, `episode_tail_known` | Independent boundary quality; a stored definite event is not proof that no unknown earlier/later event occurred |
| `episode_bytes`, `episode_events` | Known raw episode increments, including zero-byte events |
| `episode_bytes_complete`, `episode_events_complete` | Independent sticky whole-episode completeness |
| `episode_member_reset_coverage` | Known actual-point reset intersects the measured episode interval; trailing confirmation-only reset does not count |
| `episode_duration_ticks`, `episode_duration_valid` | Actual tail minus first timestamp when all required boundaries are known and the duration is positive |
| `episode_e2e_gbps`, `episode_e2e_valid` | Raw bytes divided by actual duration, valid only for normally completed byte-complete episodes |
| `episode_result` | Latest immutable `bw_episode_result_t` final payload; sequence 0 means no result has been emitted |

A zero value with validity false is unavailable, not a measured passing zero.
Own reset clears current episode fields to `NONE`; the final payload retains the
interrupted record and its old epoch. Episode and final sequences never rewind.
No activity creates no fabricated zero-byte episode. Current duration can be
known while Q confirmation is pending, but complete e2e remains invalid until
normal completion. No steady phase is required for valid e2e.

`bw_episode_result_t` includes typed scope, statistics epoch, final sequence,
episode identity/status/reason, boundaries and their quality, raw counts,
independent completeness, reset coverage, duration/e2e validity, and cumulative
start/end count snapshots. The synchronous result-delivery contract is:

```systemverilog
emit_episode_result(string scope_id, bw_episode_result_t result);
```

The identity string and static payload are passed by value together. VCS rejects
regular output ports of structs containing dynamic strings, so the public point's
existing `scope_id` supplies identity while the static `episode_result` payload
can be connected as an ordinary output. The synchronous function receives every
final record, including multiple records drained in one time slot and final-block
truncations; a toggle pulse is not its delivery guarantee. The package is a
bridge, and episode arithmetic stays in the core. The dedicated check/report
owner receives this bridge synchronously for scene expectations.
`BW_EPISODE` logs final statistics and reasons; configured metrics also produce
`BW_CHECK` conclusions and one final `BW_SUMMARY`. No user-side read/ack or timing
action is required. See the [complete supported cfg keys and report API](bw-mon-expectations.md).

At the normalized group/core boundary, pending source progress also gates ns
window and Q publication. A delayed earlier frame cannot be mistaken for zero
activity; reset or observation end with prior pending input reports partial
counts and end-boundary quality. This internal coordination needs no additional
integrator action. Controls wholly inside this scope's own reset do not poison
a new epoch after known release.

Independent regressions cover `[80,102)` with 256 B (128/11 GB/s), a deadline
transfer at 132 ns, stopped clocks and 98 ns actual tail periods, middle/before/
after-event gaps, unknown size, complete recovery separators, no-edge reset
controls, same-deadline NBA reset, a valid zero-byte episode, no episode,
truncation, delayed-input progress and partial settlement, explicit-Q errors
and the immutable final time budget. Integer
counts/times/qualities compare exactly; real results use 1e-10 GB/s numerical
tolerance. `python3 tests/run.py` reproduces the full suite; the `episode_*` case names
in `tests/cases.json` select the episode regressions individually.

## Automatic traffic phases

Set `EPISODE_ENABLE=1` to enable episodes and the fixed default phase strategy.
Omitted `PHASE_ENABLE` follows the episode switch. Explicit `PHASE_ENABLE=0`
retains episode statistics without phases; explicit 1 requires enabled episodes.
Both switches accept only known 0/1. Q defaults to 10 in the selected basis and
remains independent of phase confirmation.

Point, group and shared core use the internal `PAIR6_R2` policy. The old N,
minimum-span, K and ABS/REL module parameters have been removed; there is no
expert override. Existing integrations must remove those arguments and recompile.
Repository VCS entries use `-error=AOUP`: VCS otherwise warns and ignores an
undefined parameter override. Custom VCS build commands should retain this flag
so removed options receive the simulator's native elaboration error.

| Internal rule | Fixed behavior |
| --- | --- |
| Evidence | Six consecutive eligible raw windows |
| Fit | Three adjacent-pair mean points, using actual physical timestamps |
| Minimum span | min(W, 5×S), in the window basis |
| Confirmation | Two consecutive equal candidates |
| Steady entry / hold | Absolute fitted total change ≤4% / 8% of the six-window mean; raw residual RMS ≤10% / 12% |
| Ramp / fall | Absolute fitted total change ≥10% of the mean; paired-point residual RMS ≤2.5%; sign determines direction |
| Zero | All six zero-valued eligible windows support STEADY; no activity creates no episode |

All absolute coefficients are zero. Raw window observations and their residuals
remain available; the pair fit does not smooth the measurements used for
variation or performance checks. Stage recognition is independent of a
performance verdict.

Eligible evidence is new, full, byte-complete, positive-denominator and owned by
the active episode. Before a new episode, all older activity is at or before
its latest retired transfer. Therefore the window includes older activity exactly
when its left boundary still includes that transfer. This private ownership
marker includes zero-byte events and uses the scope's episode identity, never
source reset generation. Unknown older observations independently fail window
quality until they expire. Own statistics reset clears this ownership with the
window history. Known silent background is not other-episode activity.

The six consecutive eligible results must also satisfy the fixed minimum span.
Fit time uses actual physical timestamps, with integer tick differences taken
before real conversion, including cycle mode after a frequency change. The
six-window mean supplies the relative scale. `phase_fit_rms` is the raw-window
residual RMS against the paired fit; `phase_fit_trend_rms` is the three-pair
residual RMS. Neither is the performance population standard deviation.

Strict steady/ramp/fall conditions use entry tolerances; an existing steady
phase uses wider exit tolerances. A changed candidate starts its K count at1.
Confirmation preserves the first candidate publication time and its raw-count
snapshots as the boundary, and exposes the later confirmation time separately.
Invalid observations immediately clear evidence/candidates and return to
undetermined without waiting K. Valid fits can also confirm departure to
undetermined after K; undetermined intervals are gaps, not reliable final
phase records. New episodes start fresh evidence. Held cycle snapshots create
no new observations or confirmations.

Public ordinary point fields are:

| Fields | Meaning |
| --- | --- |
| `phase_strategy`, `phase_reason` | Fixed strategy version and typed explanation; `phase_reason_name()` gives DISABLED, NO_EPISODE, warmup/quality/ownership exclusions, evidence shortage, confirmation progress or confirmed state |
| `phase_evidence_required`, `phase_candidate_required`, `phase_minimum_span` | Fixed six-sample/two-confirmation requirements and actual min(W,5S) in the selected basis |
| `phase_current`, `phase_candidate`, `phase_active` | Current/candidate `BW_PHASE_UNDETERMINED`, `RAMP`, `STEADY` or `FALL`; active means a confirmed reliable fragment exists |
| `phase_id`, `phase_result_seq` | Lifetime confirmed-fragment identity and delivered final-fragment sequence; discarded outside-episode fragments can leave ID gaps |
| `phase_window_seq` | Last consumed window `result_seq`; unchanged on a held cycle snapshot |
| `phase_eligible`, `phase_evidence_continuous`, `phase_evidence_sufficient` | Independent current-observation and N/span qualification |
| `phase_evidence_count`, `phase_evidence_span` | Retained consecutive count (at most N); span is integer ticks in ns mode, actual edge indices in cycle mode |
| `phase_candidate_count`, `phase_candidate_ticks` | Consecutive candidate count and first-candidate time |
| `phase_candidate_total_bytes`, `phase_candidate_total_events` | Known raw cumulative snapshots strictly before that candidate publication |
| `phase_start_ticks`, `phase_confirmation_ticks` | Confirmed current boundary and later confirmation time |
| `phase_fit_valid`, `phase_fit_mean`, `phase_fit_delta`, `phase_fit_rms`, `phase_fit_trend_rms` | Latest qualified fit in GB/s; invalid evidence clears validity rather than extending an old fit |
| `phase_result` | Latest immutable static `bw_phase_result_t` final record |

The synchronous bridge is `emit_phase_result(string scope_id,
 bw_phase_result_t result)`. Like episode delivery, identity is separate by-value
string context because VCS regular struct output ports cannot contain strings.
The static record includes typed scope, epoch, episode/phase/final identities,
phase kind, final half-open bounds and independent known flags, original raw
count snapshots, confirmation time/fit, end reason and episode status at
submission. Counts are known raw counts, not a completeness proof or a sum of
overlapping windows. Interval-byte completeness, raw bandwidth, variation
and final last-steady representative selection are described below.

Closed fragments stream when their end is guaranteed inside already observed
episode coverage. Their recorded episode status can still be ACTIVE: later
incomplete traffic does not undo an earlier known phase interval. Fragments
whose end can still be clipped are retained until the episode settles. Final
clipping uses the actual tail and corresponding count snapshot; a phase wholly
after the measured episode is discarded. Unknown ends remain unknown, and an
unconfirmed candidate never becomes a formal fragment. Own reset clears current
phase fields/evidence while preserving old-epoch final records and lifetime IDs.

A confirmation may occur after the last transfer while the independently
configured Q is still collecting silence. Final intervals are clipped to the
actual episode tail. Insufficient phase evidence never invalidates an otherwise
complete positive-duration episode average. The fixed-input product suite covers
constant and repeated platforms, rise/fall, alternating ±2% and ±8%, short
activity, zero-byte activity, no activity, gaps and reset recovery.


## Final interval metrics

Enabled episodes collect variation even with `PHASE_ENABLE=0`; enabling phases
also produces final per-fragment metrics. There are no additional universal
thresholds or user history capacities. Calculations and retained evidence belong
to the shared core; package emitters provide static by-value transport and logs.

Each `bw_phase_result_t` now includes known raw `byte_count` / `event_count`,
`duration_ticks`, `bytes_complete`, `events_complete`, `member_reset_coverage`,
`duration_valid`, `bandwidth_valid`, `duration_reason`, `bandwidth_reason`, and
real `bandwidth_gbps`. Duration is the actual physical difference between final
known boundaries, including for cycle windows and stopped or changing clocks.
Raw bandwidth is final raw bytes divided by that duration. The same fields are
available for every reliable fragment; the steady-phase performance metric uses
the selected final steady fragment. A later unknown size can invalidate a
fragment's raw bytes while leaving its duration and selected window variation
valid. Unknown size preserves definite event completeness. No-edge unknown reset
intervals independently mark raw bytes and events incomplete; known member reset
coverage is recorded without invalidating known group bytes.

Raw quality uses exact boundary snapshots of unknown record counts, unknown
event-record counts and elapsed physical ticks covered by any unknown control.
The control tick measure is a union, so simultaneous unknown members do not
multiply the duration. Record increments at the right endpoint are excluded;
control intervals ending at the left endpoint do not overlap. These prefixes
are independent of sticky whole-episode quality and are reset only with the
scope's statistics history. Public records retain the start/end prefixes for
rechecking completeness. Delayed member controls from before a new statistics
epoch still validate their original sequences/receipts and refresh member state;
they do not replay pre-epoch unknown duration. Known recovery before the epoch
cannot poison fresh activity, while unknown coverage persisting after release
retains its independent incomplete quality.

Both final phase and episode records contain static `bw_variation_result_t
variation` with these fields:

| Fields | Meaning / units |
| --- | --- |
| `window_basis`, `window_width`, `update_stride` | Window configuration; width/stride in ns or local cycles |
| `sample_count`, `first_sample_ticks`, `last_sample_ticks`, `sample_span_ticks` | Qualified new publication count and actual physical publication span |
| `mean_gbps`, `min_gbps`, `max_gbps`, `stddev_gbps`, `cv_pct` | Equal-weight window mean/extrema, population sigma and percent CV |
| `interval_known`, `coverage_complete` | Independent final boundary and otherwise-eligible observation coverage |
| `minmax_valid`, `stddev_valid`, `cv_valid` | At least1, at least2, and at least2 with positive mean, respectively, plus known final interval/coverage |
| `minmax_reason`, `stddev_reason`, `cv_reason` | Independent metric evidence reason |
| `excluded_warmup`, `excluded_foreign`, `unknown_samples`, `excluded_denominator` | Publication qualification context; normal exclusion counts may overlap |

Selection uses publication times in the final half-open interval `[a,b)`,
including a sample at `a` and excluding a sample at `b`. Eligible windows may
cross stage boundaries within the same episode. Samples begin with publications
owned by the active episode; the publication before its first raw event does
not become a new analysis sample afterward. A held cycle snapshot is never
sampled again. Cycle frequency changes retain equal publication weights rather
than weighting by physical duration. Population sigma uses the selected sample
mean, not the raw byte/time ratio or the phase fit residual RMS.

Warmup and known foreign-episode activity, including old zero-byte transfers,
are normal exclusions. An otherwise-eligible unknown observation increments
`unknown_samples` and makes the interval's variation unavailable; dropping that
sample cannot restore complete variation. These conditions are independent of
raw episode bytes/e2e. For example, an unknown-size final event can make e2e
unavailable while its unknown window is published exactly at the excluded tail,
leaving earlier selected window samples complete. CV with mean0 is unavailable;
a valid zero sigma remains available with at least2 samples. No epsilon or
clamping changes either condition.

Metric reasons use `bw_metric_reason_t` with `BW_METRIC_` prefix: `OK`,
`BOUNDARY_UNKNOWN`, `BYTES_UNKNOWN`, `OBSERVATION_UNKNOWN`, `NO_SAMPLES`,
`TOO_FEW_SAMPLES`, `ZERO_MEAN`, `RESET`, `TRUNCATED`, `NO_STEADY`. A whole episode's
formal variation requires normal completion and a known final interval/coverage;
interrupted/truncated records retain unavailable reasons. Unresolved phase
metrics also retain RESET/TRUNCATED reasons rather than losing their interruption
context behind a generic boundary reason. A previously settled
complete phase remains valid after a later gap, reset or observation end.

The fixed default sustained-variation rule is separate from these explicit
variation metrics. With phase analysis enabled it needs no `BW_EXPECT` file:
`bw_check_report` builds the earliest six consecutive fully platform-contained
windows with logical span at least `min(W,5*S)`, freezes their mean B, and checks
the reference rows too. Strict `abs(y-B)>0.05*B` must hold for >=2 consecutive new
valid rows spanning W in original ns-tick/cycle positions to FAIL. Equality,
CV and phase-fit residuals do not redefine this rule. Zero/missing reference or
incomplete coverage warns; positive near-zero references follow the same rule.
Every platform settles once at terminal episode attribution, preserving earlier
FAIL and keeping explicit metric counters independent. See
[expectation and report contract](bw-mon-expectations.md#default-sustained-variation-check).

Phase records additionally retain original recognition support in
`support_first_seq`, `support_last_seq`, `support_count` and
`support_min_gbps`/`support_max_gbps`. The fixed first confirmation uses seven
original valid rows; advancing the six-row fit does not replace that support.
Private raw evidence preserves both window endpoints and actual cycle positions
for final reference/cutoff checks. `BW_DEFAULT_CHECK` reports B separately from
raw steady bandwidth and includes reference membership, runs, quality and reason;
`BW_DEFAULT_EXCLUSION` reports independently confirmed phase ranges. Normal-step
handoff attribution is a separate following implementation requirement.

Episode records also contain `last_steady_found`, `last_steady_selection_valid`,
`last_steady_reason` and embedded immutable `last_steady`. Only a normally
completed episode with a known last transfer and actual tail makes representative
selection formal. An unknown episode start can invalidate e2e while a later
complete steady interval remains comparable. Reset, truncation, or an unknown
last transfer/tail leaves representative selection unavailable. The embedded
result preserves the original phase identity/result
sequence and its independent metric validity. Intermediate phase emissions
report their own final intervals without declaring a formal last representative.
Multiple steady intervals are allowed. A later good interval cannot erase an
earlier performance failure.

Settled samples accumulate online using mean and centered second moment,
count and extrema. Samples whose ownership may change under K backdating or
whose inclusion may change under final tail clipping remain retained exactly.
A later definite transfer can settle an earlier internal pause; trailing
confirmation samples remain excluded. For an already closed fragment while the
tail is unknown, accounted observation through min(current physical time, input
progress watermark) proves no earlier next edge can cut it. This lower bound
settles that closed fragment's samples only; it never creates a tail/e2e endpoint
or closes an otherwise still-open phase at observation end. This does not retain every result for the
whole simulation. Queue growth, counters, quality-time arithmetic and real
representation are checked; failures are terminal `METRIC_TIME`,
`METRIC_ARITHMETIC` or the common checked-storage/arithmetic diagnostic. Final
emission explicitly respects the shared terminal/deferred-failure guard, because
this VCS version can continue after a fatal call within `final`.

Fixed point scope flattens the immutable records into ordinary scalar aliases:
`phase_duration_ticks`, `phase_byte_count`, `phase_event_count`,
`phase_duration_valid`, `phase_bandwidth_valid`, `phase_bytes_complete`,
`phase_events_complete`, `phase_member_reset_coverage`, `phase_bandwidth_gbps`,
`phase_duration_reason`, `phase_bandwidth_reason`; variation fields, including window basis/W/S, have `phase_variation_` or `episode_variation_` prefixes.
The selected representative has `episode_last_steady_found`,
`episode_last_steady_selection_valid`, `episode_last_steady_reason`,
`episode_last_steady_phase_id`, `episode_last_steady_start_ticks`,
`episode_last_steady_end_ticks`, `episode_last_steady_bandwidth_gbps`,
`episode_last_steady_bandwidth_valid` and `episode_last_steady_variation_*`.
Immutable identities are also flattened as `episode_result_stats_epoch`,
`episode_result_episode_id`, `phase_result_{stats_epoch,episode_id,phase_id}`,
`phase_result_{start,end}_ticks`, `phase_result_{start,end}_known`,
`phase_result_{start,end}_total_{bytes,events}`, and
`episode_last_steady_{stats_epoch,episode_id,result_seq}`. They keep latest-final
context separate from the currently active epoch/episode/phase. The immutable
record's sequence identifies when these aliases change. Existing
window/evidence/current phase scalars keep their original meanings.

`BW_PHASE_METRICS` logs raw count/time/bandwidth and quality prefixes.
`BW_VARIATION` logs scope/epoch/episode/phase/result identities, final interval,
window configuration, sample times/count, values at17-digit precision, independent
validities/reasons and exclusions. Unavailable sigma/CV print `UNAVAILABLE`;
public real storage0 with a false validity flag is a placeholder, not a measured
zero. `BW_LAST_STEADY` accompanies the final episode
and records selection status plus the original final phase identity. These are
statistics context; configured comparisons remain owned by check/report.

Independent raw-input regression examples (all integer facts compare exactly;
real calculations use numerical tolerance1e-10 GB/s or percentage points):

| Test | Independent expected result |
| --- | --- |
| `metrics_delayed` |640 B at95 and0 B at135, W100/S10: final steady[120,136), raw0/16=0 GB/s, window samples120/130 both6.4; episode uses four6.4 samples |
| `metrics_repeated` |24 raw values10,10,10,20,30,40,40,40,30,20,10,10,10, then eleven20s: episode23 samples, mean480/23, variance45600/529, CV44.4878260501%; last steady[17,25), raw160/8=20 and eight20-valued samples. Last-event100 variant changes raw steadyBW to30, keeping variation unchanged |
| `metrics_actual_clock` |10/12/16 at11/12/14 ns or10.5/11/12 ns: equal-weight mean38/3, variance56/9, sigma2.49443825785, CV19.6929336146%; raw phase durations use actual later edges |
| `metrics_zero`, `metrics_small` |Zero mean with3 samples gives valid sigma0 and unavailable CV; one-sample steady gives min/max only; episode-only0/1/2 samples and ordinary warmup remain distinct |
| `metrics_quality`, `metrics_independent` |Unknown raw bytes and unknown selected window coverage have independent effects; definite unknown-size transfers keep event counts complete |
| `metrics_controls`, `metrics_exclusions` |No-edge unknown versus known member-reset controls; later independently complete stages; old zero-byte residue/left equality and normal warmup versus actual unknown publication coverage |
| `metrics_late_recovery` |Original unknown control2.5/recovery3.5 delivered with raw frame10: old ambiguous episode completes at originalQ7.5 using saved quiet quality prefix; new[10,11) episode remains complete8 GB/s; reset modes distinguish pre-epoch/equal-left recovery from actual member or own-control gaps after release |
| `metrics_stopped_history` |Clock stops after last transfer6; closed ramp[6,8) retains duration2/raw20 and selected30/40 sigma5, while tail/e2e/current phase remain unavailable at truncation |
| `metrics_interrupted` |Settled ramp[6,8) has raw40 GB/s and duration2 ns, selected30/40 windows give sigma5 despite fitRMS0; later reset/truncation leaves it valid and representative selection unavailable |

Reproduce with `python3 tests/run.py` or pass any listed case name. These
component/raw-point vectors do not claim full group composition, waveform manual
review or target-scale acceptance.

Missing-stage diagnostics run in the writable native coordinator after explicit current continuations and producer certificates are exhausted. Read-only contract observers verify the final state at the original timestamp. A scoped runtime failure preserves healthy sibling episode/hint output. Positive-time old-edge input is invalid and cannot revive a disabled scope. The unified final-report responsibility audit remains separate from local completion.

The compile-cache fingerprint includes ROOT, runner content/options, absolute
compilation-unit paths/content, explicitly listed `case.sources` fixtures, the
selected top, and all recursive RTL `.svh`/`.vh` content. This includes nested
library headers and invalidates stale binaries after flag/fixture/header edits.

Ticket18 baseline integration validation: **146/146 contract cases passed** on
2026-10-24 with VCS W-2024.09-SP1_Full64 and Python 3.6.8, including all 101
previous integration cases and 45 aggregation/deferred-final cases. All 102 compile
logs contain no Warning-/Error- diagnostics; source/fixture/header/runner cache
fingerprints match the current tree. `git diff --check` passed. That run established
single-level functional evidence. The hierarchy validation below extends it; full
group analysis, real waveform review and scale/history acceptance remain separate
tickets.


## Typed hierarchy and independent statistics

The T4 topology uses twelve registered points, including ungrouped p10/p11, and
four real group instances, with Group IDs `die0_dmc`, `die1_dmc`, `all_dmc`
and `mixed`. Their t=0 member rules include:

```systemverilog
// Add points p0...p3 to die0_dmc and p4...p7 to die1_dmc.
add_group_member("all_dmc", "die0_dmc");
add_group_member("all_dmc", "die1_dmc");
add_group_member("mixed", "die0_dmc");
add_point_member("mixed", "p8");
add_point_member("mixed", "p9");
// The one setup seals all rules automatically after the t=0 slot.
```

`all_dmc` has two direct members and eight recursive points; `mixed` has three
and six. Combining both into one further group fails because p0...p3 occur on two
paths. The same `die0_dmc` source supplies both parents with independent durable
acknowledgements. Its completed point input records can be released while its
single group record waits for the slower parent. Ancestors consume only direct
source records; they do not receive copies of every leaf stream.

A local point/group statistics reset clears only that scope's history and epoch.
The group collector, original-time raw sequence, publication, core receipt and
input acknowledgements continue while its statistics reset is held. Parent and
other-parent histories continue independently, including when the reset group
rewarmups. A group statistics reset sends no actual-point reset notification.
Actual point controls preserve the originating point, control sequence, source
epoch and original timestamp across every level, including clock stop. Known
reset coverage remains distinct from unknown byte/event quality.

The `hierarchy_t4_{ns,cycle}_{normal,child_reset,point_reset,size_unknown}` cases
instantiate twelve public points using all three protocols and fixed/dynamic
bytes, plus four automatic groups. At T=104 ns / edge208, the literal E1 raw
vectors are respectively 256/4, 512/8, 384/6 for child/all/mixed; known p0 reset
changes these to 192/3, 448/7, 320/5 with complete bytes and reset coverage;
unknown p0 size gives 192/4, 448/8, 320/6 with incomplete bytes and complete
events. The child-reset case preserves the normal vector. Additional parent-reset
cases check that the shared child and its other parent retain their statistics.
At 2 GHz and 64 B/point, full-window GB/s are 128 per point, 512 per die, 1024 for
all and 768 for mixed; cycle B/cycle values are 64, 256, 512 and 384. Integers are
exact; small-vector real calculations use absolute tolerance 1e-10.

`hierarchy_retention_{all_first,mixed_first}` changes lawful parent completion
order on consecutive original edges for all four E1 scenarios, and verifies
retained frames, independent quality and final sums through the controlled
package seam. `hierarchy_depth_transport` sends a leaf through same-time
NBAs and eight group levels at its actual original edge; all levels keep
T/edge and complete in that same physical slot. Its three maximum-size point
increments produce exactly 12,884,901,885 B at the root; the real tolerance 1e-4
GB/s is below 8e-15 relative. The matching missing case quarantines the affected ancestor path at the original edge timestamp while reliable leaves continue. Clock-stop known/unknown point
controls, their expiry and a reset of a middle group with existing history are
also checked. A sampled observation gap retains the other points' known bytes
and events through all eight levels, with both completeness flags false. A later
actual edge while a middle group remains held in statistics reset still advances
its own raw source, core receipt and input acknowledgement. Its ancestors recover
a complete window independently of that group's local statistics held in reset.

Startup cases cover typed equal-text IDs, duplicate direct subgroup rules,
point/subgroup/sibling/diamond overlap with both paths, conflicts beyond 32/64-bit
point-index boundaries, cycle paths, missing typed references, depth 8/9 and
fanout 16/17. `hierarchy_edge_limit_{exact,excess}` accepts 65,536 edges and rejects
65,537 with 4,096 groups/points. This proves startup validation only; it does not
claim the maximum-duration or maximum-point scale workload. Recursive membership
still uses one 16,384-bit mask per group (8 MiB at 4,096 groups), plus bounded
traversal/depth metadata. Transport keeps one source backlog and independent
positions per direct edge, separate from local statistics history.

Run named cases with `python3 tests/run.py <case>...`; `tests/cases.json` contains
the complete `hierarchy_*` matrix. Shared T4 fixture compilation units participate
in the same cache digest as recursive RTL headers, source paths and runner flags.


Before merging ticket 25, hierarchy validation passed **188/188 contract cases** on
2026-10-24 with VCS W-2024.09-SP1_Full64 and Python 3.6.8: all 146 prior cases
and 42 hierarchy cases at integration 6ad39d9. All 110 compiled tops had no
Warning-/Error- diagnostics. The source, recursive-header, explicit-fixture and
runner fingerprints matched that tree;
every runtime log follows its current compilation stamp. `git diff --check` passed.
This includes the final forward-reference, sampled-gap and held-upper-reset
fixtures. That hierarchy-only run did not include full group analysis; ticket26 composition
below adds its parameters/aliases and comparisons. Real waveform review and scale
execution remain separate acceptance work.

An additional malformed-configuration startup probe creates a 4,096-group chain
and correctly terminates at time zero with `GROUP_DEPTH`, depth 9, maximum 8 and a
nine-group path. This VCS build reported automatic stack growth to 50,084,512 bytes
during that invalid graph traversal. This is startup diagnostic resource behavior;
it is not maximum-scale functional/runtime evidence or a maximum-RSS measurement.


After merging integration d9fad43 (the point report owner), **250/250 current
contract cases passed** across **119 compiled tops**: all 208 integration cases
and 42 hierarchy cases. The full invocation passed 238 cases; three initial
compile targets could not connect to the license server, affecting twelve cases.
Only those twelve cases were retried, and all twelve passed with unchanged source.
Their original infrastructure logs and retry transcript are retained separately.
All final compile logs have no Warning-/Error- diagnostics, all source/header/
fixture/runner fingerprints match, and every runtime log follows its current
compilation stamp. The audit rechecks the current `expect_log` and `expect_counts`
predicates, including exactly one final summary with 16/16 scopes in every T4
mode and 5/5 in the equal-text point/group identity case. A focused three-case
report-barrier run also passed. Group analysis aliases/comparisons are delivered
below; real waveform review and nominal scale execution remain later acceptance work.

## Group analysis and immutable public aliases

`bw_group_mon` accepts the same explicit `EPISODE_ENABLE`, `SILENCE_THRESHOLD`,
`PHASE_ENABLE`, N/min-span/K and all ten fit-threshold parameters as
`bw_point_mon`. The analysis-enable parameters retain a raw four-state2-bit value until validation;
only known0/1 is legal. Defaults disable both analyses; enabling phases requires enabling
episodes and supplying the complete valid configuration. Validation occurs before
registration can advertise Ready. A group has its own core, epoch, episode/phase
identities and quality. Resetting its local `reset_n` interrupts only its own
analysis; its raw group source continues serving parents. Known member reset is
coverage metadata, not automatic group-byte failure.

All episode/phase/metric scalar names documented for points also live directly at
the public group instance. `rtl/bw_analysis_public.svh` shares declarations at that
same scope; it creates no extra hierarchy. Scripts must use the public instance,
not a private `.core` or package queue. Additional immutable aliases keep the latest
final packet readable while a new episode is live:

| Fields | Meaning |
| --- | --- |
| `episode_result_stats_epoch`, `episode_result_episode_id`, `episode_result_result_seq` | Latest immutable episode identity, separate from live fields |
| `episode_result_first_ticks`, `last_ticks`, `tail_ticks`, `confirmation_ticks` (all with `episode_result_` prefix) | Immutable first/last/actual-tail/confirmation timestamps, fs |
| `episode_result_byte_count`, `event_count`, `duration_ticks` (same prefix) | Immutable raw totals and physical duration |
| `episode_result_status`, `episode_result_reason`, `episode_result_e2e_gbps` | Immutable lifecycle/reason/raw BW |
| `episode_result_first_known`, `last_known`, `tail_known`, `bytes_complete`, `events_complete`, `duration_valid`, `e2e_valid`, `member_reset_coverage` (same prefix) | Independent immutable qualities |
| `phase_result_stats_epoch`, `phase_result_episode_id`, `phase_result_phase_id`, `phase_result_result_seq` | Original immutable phase identity |
| `phase_result_kind`, `phase_result_end_reason`, `phase_result_episode_status`, `phase_result_confirmation_ticks` | Final phase type/context/confirmation |
| `episode_last_steady_*` | Selected original phase identity, start/end/confirmation, raw byte/event counts, duration and validity, BW and validity, start/end knownness, byte/event completeness, member reset, duration/BW reasons |
| `phase_variation_window_basis/window_width/update_stride`, `episode_variation_*`, `episode_last_steady_variation_*` | Variation configuration alongside the existing sample/value/quality aliases |

All counters/timestamps are unsigned64-bit; flags are ordinary bits; states/reasons
are enums; BW/sigma/CV/mean are real. A zero backing value for an unavailable metric
is not a measurement: inspect its validity/reason. `window_mean` is variation
context and is distinct from raw interval BW. Full supported target keys, evidence
requirements, stream deduplication and final barrier are in
[Expectation configuration and reports](bw-mon-expectations.md).


## Exact numeric boundaries and automatic retention

See [numeric/storage contracts](bw-mon-numeric-storage.md) for raw-before-narrowing
configuration and metadata validation, checked unsigned arithmetic, exact event/
clock/publication runs, independent source ACK retention, contextual test-only
allocation rejection and reproducible resource evidence. Public names and numeric
widths remain stable; malformed policies cannot become known-zero accounting.

## Ending audit and the one report-complete marker

Simulation ending depends on no final-block order. The first owner to reach
its final runs one idempotent global audit (`BW_END_AUDIT`), freezing the
durable responsibility ledger; every point and group then leaves a typed
terminal line `BW_POINT_TERMINAL` / `BW_GROUP_TERMINAL`
(`state=NORMAL|UNOBSERVED|DISABLED|INTERRUPTED`, with the responsible
`stage=` on interruption). After all SV finals, one native end-of-simulation
callback verifies every registered owner/core/hint role receipt and every
scope terminal, then emits exactly one `BW_REPORT_COMPLETE` line carrying
`roles=k/k terminals=m/m summary=0|1 integrity=COMPLETE|INCOMPLETE
performance=PASS|FAIL|WARNING|STATISTICS_ONLY|NONE`. Monitoring integrity is
named independently of the process exit and the performance summary; a
quarantined or interrupted scope makes the marker `integrity=INCOMPLETE`.

When any receipt or terminal is missing, the marker is replaced by exactly one
`BW_REPORT_INCOMPLETE reason=...` line and no completion marker is backfilled.
The reason family is closed:

| reason | meaning |
| --- | --- |
| `CORE_FAILURE` | a fatal core error already stopped monitoring |
| `NO_END_AUDIT` | no owner final ever ran the global audit |
| `NOT_READY` | monitoring never published ready (carries `stage=`) |
| `MISSING_ROLE_RECEIPT` | a registered owner/core/hint role left no terminal receipt (carries `owner=`/`role=`) |
| `MISSING_SCOPE_TERMINAL` | a registered scope left no terminal line (carries `scope=`) |

An externally killed or stalled process produces neither marker nor summary;
that absence is the external evidence of an unclean ending and is never
replaced by invented in-library missing-frame diagnostics. Drivers that finish
in the same time slot as their last posted input honestly settle as
`INTERRUPTED stage=GENERATION`; advancing one representable slot after the
endpoint lets the final generation close normally.

## Reproducible end-to-end scenes

The [acceptance handoff](bw-mon-acceptance.md) is the current integration/config,
D/T-to-evidence and human-review index. `make acceptance` runs the real twelve-
point/four-group scenes through one module-type bind and public setup/group APIs.
The standalone reference uses original input rows and Fraction arithmetic; it
never reads monitor code as a golden model. See the checked-in source
[`scene.sv`](../tests/acceptance/scene.sv), configurations, original FSDBs, portable
public views and expected/actual tables under `artifacts/acceptance` after local
generation or explicit restoration. The current PR keeps screenshots and final
summaries; use the [evidence guide](bw-mon-evidence.md) to restore recorded data
without committing waveform files or intermediate results again.

The earlier per-ticket run counts above are historical, explicitly scoped proof.
The current427-case proof, historical424/408-case component proofs and fresh42-scene evidence are
indexed by the acceptance handoff. Actual human review remains separate from
agent image inspection; maximum-scale evidence is owned by its scale tickets.
