# Bandwidth monitor integration and public results

The current implementation covers ns and local-cycle observation-point windows
from [绑定观测点并发布 ns 滑窗带宽](https://github.com/MakeReadUnique/bw_mon/issues/14)
and [cycle 滑窗、停钟与变频](https://github.com/MakeReadUnique/bw_mon/issues/16),
and three-protocol accounting from
[三类接口的逐传输计量与观测缺口](https://github.com/MakeReadUnique/bw_mon/issues/15).
The remaining implementation tickets extend this same public contract.

## Compile and start

Compile `rtl/bw_mon_pkg.sv` before the other `rtl/*.sv` files. All production
scopes use `timeunit 1fs; timeprecision 1fs`; timestamps are unsigned 64-bit integer
femtosecond ticks, read directly with `$time` in that scope. A nanosecond is
1,000,000 ticks. Do not override production time units or precision.

```systemverilog
// Once for every target module instance of this type:
bind data_port bw_point_mon #(
  .WINDOW_WIDTH(10), .UPDATE_STRIDE(1), .FIXED_BYTES(64)
) bw (.clk(clk), .reset_n(reset_n), .valid(valid));

// Once in the testbench; include every point, including ungrouped points:
bw_mon_setup #(.EXPECTED_POINT_COUNT(12)) bw_setup();

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

Registration and configuration each explicitly notify startup state. Startup
does not infer completion from process ordering, a zero-delay barrier or a queue
being temporarily empty. The last required registration freezes the configuration
and records `bw_mon_pkg::measurement_start_ticks`. Before that, no sampling edge
contributes. A setup watchdog terminates an incomplete startup in simulation time;
an active-region registration at the exact deadline participates before that
decision. An edge at the common start itself is excluded.

## Initial configuration

| Object | Parameter | Type / unit | Requirement and illegal behavior |
| --- | --- | --- | --- |
| setup | `EXPECTED_POINT_COUNT` | unsigned 32-bit count | Required, 1..16,384; zero or excess is fatal |
| setup | `STARTUP_TIMEOUT_NS` | unsigned 64-bit integer ns | Default 100, positive; missing points at deadline are fatal |
| point/core | `WINDOW_BASIS` | `bw_basis_t` | `BW_NS` (default) or `BW_CYCLE`; fixed before startup |
| point/core | `WINDOW_WIDTH` | unsigned 64-bit integer ns or cycles | Required, 1..40,000 ns or 1..80,000 cycles according to basis |
| point/core | `UPDATE_STRIDE` | unsigned 64-bit integer ns or cycles | Required, `0<S<=W`; uses the same basis as W |
| point | `POINT_ID` | string | Default `__BW_AUTO__`; otherwise nonempty, unique exact ID |
| point | `CLOCK_CONTEXT` | string | Default `default`, nonempty; an integration declaration, not proof of physical wiring |
| point/recorder | `FIXED_BYTES` | four-state 64-bit parameter, bytes/transfer | Default 0 (legal zero-byte transfers); fixed mode requires known value at most 2^32−1 |

The selected protocol determines whether a transfer occurred (see below). The recorder samples control
at the actual positive edge, creates one normalized record per edge, including
idle/reset/unknown states, and supplies the identical record to the local core.
Known reset excludes a transfer. Unknown reset/control marks event and byte
incompleteness; it does not invent zero traffic. Full local reset/restart behavior
is delivered by the reset ticket.

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
| `reset_n` | Original four-state reset sample |
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
| `member_reset_coverage` | At least one known point-reset sample remains in the window |
| `raw_record` | Identical normalized record used by the local core, for tracing input evidence |

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
configuration, startup timeout, frozen registration/configuration, out-of-order
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
This numerical tolerance is separate from any future performance tolerance.

| Test | Independent expectation / contract |
| --- | --- |
| `ns_bind` | One type bind to two real target instances; default IDs; transfers at 1, 2.5 and 10 ns of 64 B; `[0,10)`=128 B/12.8 GB/s, `[1,11)`=192 B/19.2 GB/s, `[2,12)`=128 B/12.8 GB/s; empty point stays independent; stopped clock eventually zero |
| `ns_stride` | Explicit identity; 8 B events at 0.25 and 2.75 ns; W=10/S=3, T=3 warmup=16 B/3 ns, first full publication T=12 with `[2,12)`=8 B/10 ns; no T=10 insertion |
| `startup_*` | Empty/duplicate ID, illegal W/S, missing point, late registration and repeated configuration terminate with precise diagnostic; exact deadline arrival succeeds |
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
| `DYNAMIC_BYTES` | bit | Default 0: count `FIXED_BYTES` on each transfer. Set 1: use that transfer's decoded `size_bytes` and `size_known` |

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

## Credit ledger and diagnostic trust

The `bw_debug_hints` component consumes the same `sampled_view`, `record` and
`record_toggle` as the recorder/core path, plus live `reset_n` for no-clock reset
notification. It never changes a normalized record or grants/blocks a transfer.
Credit parameters pass from `bw_point_mon` to this component:

| Parameter | Type / default | Meaning and rejection |
| --- | --- | --- |
| `CREDIT_ENABLE` | bit, 0 | Request ledger diagnostics; capability remains separate |
| `CREDIT_CAPACITY` | four-state logic [63:0], X | Explicit known capacity required when a credit-protocol ledger is enabled; 0..2^64−1 are legal |
| `CREDIT_INITIAL` | four-state logic [63:0], X | Explicit starting balance, used only when initial knowledge is asserted |
| `CREDIT_INITIAL_KNOWN` | bit, 0 | Unknown initial balance stays unknown; if 1, initial value must be known and within capacity |
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
| `credit_shortage_known`, `credit_shortage` | Whether the updated ledger balance can be trusted, and whether it is zero; does not prove pending demand |
| `credit_anomaly`, `credit_reason` | First trust-loss latch and reason; cleared by known reset |
| `credit_anomaly_count` | Unsigned 64-bit cumulative trust-loss count, preserved across resets; initial unknown state alone is not an anomaly |
| `credit_epoch`, `credit_result_seq` | Unsigned 64-bit reset generation and monotonic diagnostic update sequence |
| `credit_update_ticks`, `credit_record_seq` | Last diagnostic update's integer fs time and last consumed source record sequence; a reset notification does not invent a record/edge |

The last-frame permission/attempt fields become unknown when a later frame cannot
be checked. The original fault remains in its log and latched reason. Current
shortage is qualified by trust and live reset, independently from the last frame's
permission evidence. Duration thresholds and long-condition hints follow in the
separate duration-hint ticket.

Additional independently expected VCS cases:

| Test | Contract evidence |
| --- | --- |
| `credit_timing` | C=0/S=R=1 both timings; disabled and unsupported states; identical 128 B window accounting with enabled/disabled/anomalous diagnostics |
| `credit_ledger` | Literal balances 2→1→0→1→1; unknown return loses trust while definite bytes count; no-clock reset recovers seed; capacity overflow retains attempted 3; unknown send remains a genuine observation gap |
| `credit_boundaries` | Exact 2^64 permission intermediate and attempted balance; legal zero capacity; zero-byte flits still consume one credit; exact attempted −1; unknown initial value remains unknown |
| `credit_reset_unknown` | No-clock unknown reset breaks trust; direct return to 1 does not repair it; a subsequent known reset restores seed without inventing record sequences |
| `credit_config_error`, `credit_initial_error`, `credit_return_error`, `fixed_unknown_config` | Missing capacity, initial balance outside capacity, invalid timing and unknown fixed bytes terminate before any `BW_READY` |
