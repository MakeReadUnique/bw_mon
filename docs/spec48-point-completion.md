# Point completion and runtime isolation

The point path now establishes expected work from an independent native raw-clock
observer. It observes the same four-state positive-edge transitions as
SystemVerilog, excludes the measurement-start boundary, and creates no expected
edges during a stopped clock. The recorder's successful enqueue, held tuple,
source publication, and core acceptance have separate durable cumulative receipts.
Dequeuing a tuple is not publication or core acceptance.

Each posted action records the writable generation that grants its continuation.
A native writable callback audits the **previously granted** work, then grants
new continuations. It rearms while an explicit dependency remains. After those
continuations run, the audit compares independent expected edges with capture,
held, publication and core receipts, plus recorder/core/hint action and control
responsibilities. There is no point timeout, elapsed-time drain, fixed number of
delta rounds, or assumption that native callbacks run FIFO. A new raw input or
posted action invalidates its point's input-generation certificate. A certificate
covers that generation; it is not a promise that a foreign callback or monitor
output cannot cause later same-time input.

The adapter is exercised on VCS W-2024.09-SP1_Full64 with `+vpi`,
`-debug_access+all`, `-assert svaext`, and 1fs precision (see `tests/run.py`).
`tests/point_completion_observer.c` registers an independent read-only callback
from the actual input edge. It observes quarantine, healthy bytes and complete
receipts at the original timestamp. Advancing the verdict or state update by 1fs
cannot satisfy that test. An Active `assert final(function_query())` is unsuitable
for this observation on this tool: the deferred expression can retain its old
sample even when its action subsequently reads the updated state.

Runtime helpers carry a typed point/group owner separately from the diagnostic
context string. `scope_disabled(kind,id)` is sticky; `scope_failed(kind,id)` also
includes fatal and shared failures. `monitoring_root_cause[scope_key(kind,id)]`
identifies the original typed owner; `monitoring_failure_code` preserves its first
error. A source failure disables its dependent ancestors. A known local failure
warns once, stops the failed operation before its next successful receipt, and
prevents further trustworthy evidence. A genuinely shared/unknown-owner failure
conservatively disables all monitoring. Startup resource failures, configuration
lifecycle violations and late calls remain fatal. Reset cannot revive a scope.
Cancelled queues/held records retain their diagnostic state and cannot acquire
new work or successful receipts; cancellation wakes suspended workers.

Point terminal state is available through `scope_terminal_state(kind,id)`.
An actual edge/control followed by immediate finish without input closure is
INTERRUPTED, not confirmed missing. A read-only finish after target-generation
completion is NORMAL at that same timestamp. An unused point is UNOBSERVED.
Disabling a point preserves earlier reliable check FAILs, permits healthy later
PASSs, and produces a disable warning rather than ordinary NO_EPISODE settlement.

## Test and assertion migration

| Previous intent | Current evidence / disposition |
| --- | --- |
| A real last edge must complete without a subsequent clock | `point_missing_capture`, `point_held_record`, `point_missing_publication`, `point_missing_core`: independently expected exact-time warning and native read-only quarantine; healthy peer continues |
| A notification is not a receipt | `point_lost_notice`: discard the advisory core-completion wake, retain durable acceptance, and require normal completion |
| Stopped/changed clock must not invent observations | `point_stopped_clock`, `point_four_state_edges`, existing `metrics_stopped_history` |
| Finite Reactive/ReNBA input is legitimate | `point_reactive_completion`: twenty real reset assertion/release pairs, no positive-time drain, independent read-only original-time bytes/epochs |
| Startup and runtime storage have different severity | Ten existing startup storage resources remain fatal; fifteen runtime resources in `storage_failure_*` now require one warning, sticky disable and continued execution |
| A damaged recorder/core must not acknowledge work | `point_runtime_isolation`, `point_reset_capture_isolation`, `dynamic_size_error`, `cycle_edge_error`, `member_control_*`, `numeric_core_*`: verify disabled owner and unchanged success receipts |
| Shared scheduling failure must stop all points | `point_shared_scheduler`: reject actual native callback registration after ready; no accepted damaged record |
| Duplicate/reversed source metadata must not advance publication | Five `group_fault_*` source/alignment cases now require warning and typed path disable. Two old missing-frame timeout cases remain explicitly old group-protocol assertions |
| End-of-run evidence must distinguish completion and interruption | `point_finish_immediate`, `point_finish_control`, `point_finish_normal`: exact original-time terminal classification, no invented missing warning |
| Reliable FAIL survives local disable | `point_historical_fail`: real 8GB/s episode fails a 9GB/s minimum, point later disables, healthy 16GB/s episode passes; same-name healthy group remains enabled |

The early-verdict sensitivity check removes the dependency guards temporarily:
the read-only healthy-point test rejects the resulting first-callback INFLIGHT
false diagnosis. Red/green traces, the mutation source and immutable run notes
are kept in the external spec48 evidence directory, not presented as full-scale
acceptance.

## Deliberate remaining migration

This implements the point portion of spec48 D7–D10. Group expected work, direct
subscriber ACK/cancellation, subscriber-aware retention/release and arbitrary
hierarchical continuation closure remain ticket55. In particular,
`missing_record_timeout_ticks=BW_TICKS_PER_NS` is still present for groups; its
1ns timeout has not been renamed or claimed removed. Group runtime source gates
here stop propagation from a disabled point, but do not constitute the new
hierarchical protocol.

The original `tb_transport_growth.sv` 4096-record retention oracle, retention
counts and raw input remain intact. Its positive-time paused consumer is not a
valid revised completion scenario. Ticket55 must map it to real same-time
retention pressure without deleting or weakening its property. The same applies
to `tb_transport_retention.sv`, `tb_hierarchy_depth_transport.sv`,
`tb_group_deferred_final.sv` and scale M4/H6 paused-consumer constructions.

One centralized audit/report owner, all report responsibilities, exactly one
report-complete marker, final control/timer audits, arbitrary module-final order
and exact supported-budget endpoint acceptance remain ticket56. Point terminal
queries and disable-aware checker settlement are building blocks, not proof of
that unified final protocol. Final resource-error ordering is included in that
remaining audit; a point's early terminal log must not replace the final typed
trust query. Full history/scale/resource budgets and user waveform acceptance
remain later tickets.

The native coordinator currently scans registered point observers on each cut.
That cost is not a scale acceptance result; ticket60 must measure it against the
unchanged budgets and may replace the scan with active-work indexing. Legacy
group consumer numeric/ACK helpers still conservatively use the shared failure
fallback; ticket55 must give them typed consumer ownership and cancel/release
only the affected subscription. Numeric source publication, point/core/hint
work and raw point reset capture already have typed ownership here.
