# Bandwidth monitor integration and public results

The current implementation covers ns and local-cycle observation-point windows
from [绑定观测点并发布 ns 滑窗带宽](https://github.com/MakeReadUnique/bw_mon/issues/14)
and [cycle 滑窗、停钟与变频](https://github.com/MakeReadUnique/bw_mon/issues/16).
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
| point/recorder | `FIXED_BYTES` | unsigned 64-bit input, bytes/transfer | Default 0 (legal zero-byte transfers), at most 2^32−1 |

A valid-only interface counts when `valid === 1'b1`. The recorder samples control
at the actual positive edge, creates one normalized record per edge, including
idle/reset/unknown states, and supplies the identical record to the local core.
Known reset excludes a transfer. Unknown reset/control marks event and byte
incompleteness; it does not invent zero traffic. Full local reset/restart behavior
is delivered by the reset ticket.

## Normalized component boundary

`bw_point_recorder` emits `bw_mon_pkg::bw_record_t record` and toggles
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
