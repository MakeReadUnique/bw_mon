# Same-time input capture and settlement

The monitor settles queued work through a writable end-of-time callback. A
private DPI/VPI adapter in `rtl/bw_slot_settlement.c` captures raw reset changes
and requests that callback; timestamps, queues, ordering, accounting, windows,
episodes, phases, hints and reports remain in SystemVerilog. The public
integration remains point/bind, group module and unified setup.

## Build requirements

Compile `bw_mon_pkg.sv` first, then `bw_check_report.sv`, the remaining
`rtl/*.sv`, `rtl/bw_slot_settlement.c` and the testbench. Include `rtl/` for the
SV headers and the installed VCS `include/` directory for `svdpi.h` and
`vpi_user.h`.

The supported measured tool is VCS W-2024.09-SP1_Full64. Use `+vpi`,
`-debug_access` and `-assert svaext`; waveform builds use `-debug_access+all`
and `-kdb`. For example, the compiler argument list includes:

```text
-full64 -sverilog +vpi -debug_access -assert svaext
+incdir+rtl -CFLAGS -I<VCS-installation>/include
rtl/bw_mon_pkg.sv rtl/bw_check_report.sv <remaining-RTL.sv>
rtl/bw_slot_settlement.c <testbench.sv>
```

`tests/run.py`, `tests/acceptance/run.py`, `tests/scale/run.py` and the standalone
scale tracer supply these dependencies automatically. Their fingerprints include
the C source and recursive local headers. Acceptance/scale builds compile from
copied source snapshots. SDK version and compiler arguments remain part of the
run's provenance. Other simulators require a separately verified scheduling
adapter; this implementation has no fallback that silently accepts early
settlement.

## Why the boundary changed

A private Reactive program settles module NBA updates, but a program can still
drive ReNBA input changes later at the same physical time. Two public
counterexamples exposed the difference:

- A timer at2ns published old-epoch window sequence2 before a ReNBA own reset.
  Reset subsequently cleared the snapshot, while the sequence and publication
  remained observable at2ns+1fs. The correct sequence was1.
- At3ns, backpressure release preceded a ReNBA sampling edge. The hint closed
  after one complete cycle and missed threshold2, despite accepting raw edge3.
  Both complete cycles `[1,2)` and `[2,3)` belong to the prior interval.

The regressions also place reset at the third full N3 phase sample. Reset must
prevent the candidate confirmation and formal phase packet, while retaining the
correct RESET_INTERRUPTED episode. Clearing the final live phase fields cannot
undo a packet already delivered to the report owner.

## Private data path

1. Native value-change callbacks preserve each observable four-state reset level
   in an ordered SV queue at its owning public point/group scope. Point controls
   retain their original time, sequence, source epoch and point identity. The
   native scalar mapping keeps Z and X distinct.
2. At writable closure, reset queues are prepared before granting a checked
   shared settlement generation. Each recorder/core/hint worker waits for its
   requested generation. Further publication work requests another generation
   at the same physical tick.
3. Own known assertion wins before window/episode/phase settlement. Raw controls
   and size still use one Active edge view. A same-time known assertion can
   override its reset level; a release cannot promote an edge sampled under
   reset0 or X into a known transfer.
4. The point publisher copies each held frame/control into the package, then
   returns a private publication receipt. The recorder waits for that receipt
   and a following settled generation before exposing another tuple. Thus
   controls2 and3 at one timestamp remain separately readable and durable.
5. Collectors retain their original contract: durable output and local core
   acceptance precede input ACK; package-owned direct-consumer positions govern
   release. Group statistics reset keeps raw upstream supply and original point
   controls intact.

The C adapter stores callback handles, scope identities and the latest raw reset
level needed for initial capture. It allocates one observer context per owning
monitor, checks allocation/size/count failure, and removes callbacks and frees
contexts at simulation end. SV reset queues grow and drain automatically with
the existing representation/storage guards. No history depth, slot count,
positive-time drain, synthetic sampling edge or fixed number of delta rounds is
introduced. Ordinary point traffic still has its direct local core path.

The current group implementation uses independent actual-edge expectations and writable completion audits, with explicit continuation grants and producer certificates. Durable capture/held/publication/core/ACK receipts survive queue removal and advisory wake loss. Read-only observers verify original-time outcomes. Frozen topology supplies causality; active subscriptions supply release obligations. No physical missing deadline remains. The version-qualified results below describe their historical source only.

## Settlement work indexing

The native adapter audits a dirty watcher set rather than scanning every scope
on every callback. Raw clock/reset changes, posted continuations and durable
receipts mark their owning watcher. An audit that still depends on a producer
or a granted continuation keeps its watcher dirty. Native grant tracking defers
dispatch until the shared generation reaches the grant; the audit still precedes
the next generation advance. A callback never substitutes for a receipt.
Shared or fatal failure cancels native grant deferral, allowing pending watchers
to reach their existing failure guards even though the generation has stopped.
The `settle_shared_pending` contract checks that a real edge followed by a
same-time shared arithmetic failure cancels workers without accepting records
and leaves later user simulation runnable.

Watcher lookup includes both scope kind and ID. Point and group namespaces stay
independent even when their ID text is equal. Separate point and group tables
avoid nested lookups on receipt paths. Worker submodules use the same
typed lookup for timer-only work while clocks are stopped. They cache the owner
handle after registration. Requests report grants and dirty activity through a
native-state-only call; only actual VPI callback registration needs DPI context. Early
preparation requests retain the fallback until a handle exists. The
point receipt path also reuses its registered ledger and watcher, including
the sticky cancellation state; ID-only component calls retain their lookup.
Owner-local audits use the same cached failure guard as their workers. The
`settle_typed_owners` contract checks these completions through a native read-only
observer at the original statistics deadline.
Transport entries validate the group handle, then reuse its integer index for
member and cursor lookups; member-index and receipt checks remain at the entry.
Each input scan reads its frozen direct-member count once before iterating.
Every notification still reports its owner's activity before checking whether
a callback is pending, so a different owner's pending callback cannot hide it.

`BW_SETTLE_STATS` reports cumulative callback rounds, dispatched audits, created
watchers, raw clock changes, dirty audits and deferred grant checks at simulation
end. `edges` counts all observed clock transitions, including falling edges;
`deferred` counts skipped dispatches rather than completed work. Counters are
diagnostic and do not establish completion. `BW_SETTLE_PROGRESS` periodically
reports progress during long runs.

Reproduce the three maximum-topology performance checks serially with cold
compilation and the unchanged 600-second end-to-end budget:

```sh
python3 tests/scale/topology_revised.py \
  topology-max-ns topology-max-cycle topology-max-cancel-ns \
  --output-root .build/settlement-max --force-compile
```

Each bounded run records source snapshots, input hashes, independent verification
differences, stage times, host load and peak RSS in its manifest and stage
receipts. A timeout or missing verification is a failed acceptance result.

## Version-qualified evidence

Production and tests were frozen at
`8e81839423ab7db335365a5e577e25b2ebe5dcb0`. The full component campaign passed
**424/424 cases across167 tops**, with unchanged source/fixture hashes and no
compiler Warning-/Error- diagnostics. The expected unreadable-cfg case retains
its VCS file-open warning and configured FILE_UNREADABLE warning.

Three isolated mixed/pulse runs also passed using the final scale options
`+vpi -debug_access`. They check ordered `1,Z,X,0,1` controls and epochs
`0,0,0,1,1`, an independent `X,1` stream, known-assert sampling priority,
group-only reset isolation and every direct ACK. The standalone public tracer
and its intentional reference-error sensitivity run passed with those options.

The four-scope exact-budget regression checks160,000 W40000/S1ns publications,
an actual ReNBA edge at40000ns, final raw receipts and direct ACKs, then finishes
at exactly40000ns through a read-only verdict. Its four final episode packets
precede the single four-scope summary. This is a boundary regression, not a
nominal-size history or maximum-topology acceptance run.

Portable component/minimum-option evidence is indexed under
`tests/scheduling/evidence/`. Earlier408-case, FSDB/common/max recordings keep
their original source labels. Fresh endpoint/waveform and nominal-matrix
acceptance are separate requirements; no human review or nominal-scale pass is
inferred from these component results.
