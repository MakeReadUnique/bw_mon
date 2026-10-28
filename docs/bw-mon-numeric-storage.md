# Numeric and storage contracts

All physical timestamps use integer 1 fs ticks. The monitoring system has one
40,000 ns budget from its published common measurement start T; point or group statistics reset
never restarts it. Window, episode, phase, source and transport identities are
separate. Lifetime sequences and acceptance receipts do not rewind on reset.

## Types and validation

| Quantity | Representation | Validation |
| --- | --- | --- |
| Internal ticks, bytes/events, edge/record/control/notification/result/epoch counts | unsigned 64-bit `bw_u64_t` | Checked arithmetic before committing values; no wrap or saturation |
| Untrusted normalized frame numeric fields | unsigned `logic [63:0]` | Reject X/Z before order, range or arithmetic checks |
| Control timestamp/sequence/epoch and point identity | unsigned `logic [63:0]`, `logic [31:0]` identity | Validate knownness before integer/handle conversion |
| W/S | raw unsigned `logic [63:0]` | Known, 0<S<=W; W<=40000 ns or80000 cycles |
| Window/hint basis | raw `logic [1:0]` | Known BW_NS/BW_CYCLE before enum conversion |
| Dynamic-byte, enable, support and initial-knownness policies | raw `logic [1:0]` at configuration boundaries | Known0/1 before internal bit conversion |
| Protocol/credit-return policy | four-state two-bit enums | Known supported enumerator before use |
| Core scope kind / progress barrier | one-bit logic / unsigned64 logic | Reject unknown; widths retained at the core seam |
| Package handles, ACKs, progress and registry query indices | raw unsigned64; scope selector raw2 | Known and in range before narrowing/lookup |
| Container size/index | simulator signed32 index representation | Check actual growth before an index becomes unrepresentable |
| Bandwidth and final statistics | real with separate validity/reason | Exact integer differences first; finite arithmetic checked |

The installed VCS demonstrably removes X when raw values are assigned to the
old unsigned-longint or enum-bit boundaries: partial-X width with low bits1 became
width1, and partial-X metadata became known low bits. A guard after that conversion
is ineffective. Raw configuration and frame/control numeric fields now preserve
those bits until validation. Counter aliases and public signal names/bit widths
remain stable. A malformed policy cannot silently select fixed-zero accounting.

Known disabled features may leave unused thresholds/seeds unknown. Unknown initial
credit is a known policy with `CREDIT_INITIAL_KNOWN=0`; it does not invent zero
credit. Raw interface control/size/reset X/Z remains observation quality: normalized
known byte/event subtotals stay numeric while completeness flags express missing
information. Zero-byte transfers remain events. A reset_n X/Z in a valid control
is accepted independently of its numeric metadata.

`checked_add` widens to65 bits and `checked_mul` to128 bits after rejecting unknown
operands. `checked_sub` rejects a negative difference before subtraction. Time
predicates are pure; an unknown time returns false, while the checked entry reports
an INTEGER_UNKNOWN core error. The actual T+40us boundary is inclusive; the next tick
is unsupported. Decimal GB/s conversion and fitting occur only after integer time
and count operations. Credit permission/attempted balance uses65/66-bit arithmetic;
credit protocol anomalies lose trust and still retain known bytes.

Independent arbitrary-precision reference:

```
16384 * 80001 * (2^32 - 1) = 5,629,569,901,646,561,280 B < 2^64
16384 * (2^32 - 1) = 70,368,744,161,280 B per group edge
40000 ns = 40,000,000,000 fs ticks
```

The 80,001 factor is an opportunity bound. With first eligible edge .25 ns and
finish at exactly40us, there are80,000 samples and79,999 complete observed cycles.
A configured80000-cycle window can correctly remain warmup. No edge at ready or
extra drain time beyond the budget is fabricated to make that window full.

## Exact automatic retention

Core event history stores value runs with exact first/last tick and edge,
count, integer strides, per-event known byte/event increments and independent
byte/event/reset quality. Compatible singletons establish a stride; subsequent
samples must match both physical-time and edge strides. Changes start a new run.
Every raw frame still enters dispatch individually. Lifetime order, raw/quality
prefixes, activity/episode boundaries and accepted receipts keep their per-edge
semantics. No fixed-frequency denominator or time bucket is introduced.

For a left boundary L, the number of run samples strictly before L is zero when
L<=first; otherwise it is `min(count, delta/stride + (delta%stride != 0))`.
Quotient/remainder avoids overflowing delta+stride-1. Removed integer counts and
positions use checked multiplication/addition/subtraction. A sample exactly at L
stays. Partial cuts retain the exact remaining first position and count. Rolling
byte/event/unknown/reset totals continue; an entire history scan is unnecessary.

Cycle boundaries are separate exact runs of actual edges, including idle edges.
A pause or changed period starts another run. The left and current boundaries of
[k-W,k) stay available; GB/s includes the actual pause and B/cycle stays independent.
Reset clears only that scope's statistics history. Controls never create a clock
boundary, and a stopped cycle snapshot does not become a new publication.

Pending episode/phase variation suffixes also use exact publication runs. Qualified
samples combine only when represented values and qualification flags match, with
exact publication stride. For an excluded sample the numeric value is unused;
equal qualification flags can therefore combine even if the unused value differs.
Every selected sample is reconstructed and fed to Welford in the original order.
K-candidate boundaries, tail/Q clipping, exclusion counters, extrema and sample
counts remain exact. No irreversible summary consumes an unresolved suffix.

The24 byte/event/reset prefixes and unknown-control-time union remain separate
scalar snapshots. Saved quiet-start quality is retained for delayed original-time
recovery; compression never queries a past publication cursor or substitutes
physical delivery time. Closed fragments retain their individual identities and
summaries. The ordered prior-episode activity marker and one selected last steady
remain intact. Fit evidence retains its actual N samples/span.

Package transport is a different owner: one durable frame/control stream per
source, unique authoritative ACK positions per direct consumer, release through
ALL direct ACKs. A group output is durable and its core has accepted or reset-
handled it before input ACK. Local statistics reset does not clear source buffers,
change source identity or advance another consumer. Ancestors consume group raw
sources; no ancestor receives a copied full leaf event history.

## Resource accounting and failure evidence

Memory must include scope event/clock runs, actual N fit evidence, unresolved
publication/phase suffixes and summaries, control quality intervals/maps, source
unacknowledged frames/controls, per-direct-consumer cursors, group expected-edge
metadata, registry rules/identities/recursive masks, report rules/summary state,
public scalar/runtime representation and allocator overhead.

Logical payload sizes are451 bits per raw frame,225 per point control and289 per
transport control envelope. Private event/clock runs use579/320 logical bits;
pending publication runs use four64-bit positions/counts, one real and four flags
before simulator alignment. These are representation descriptions, not heap-byte
measurements. Source backlog counts are logical unread records, not a substitute
for scope history. Recursive masks use8 MiB at4096 groups. The report owner keeps
12 bounded metric-rule entries per registered scope and stream high-water marks,
not an all-scene result list. Origin control validation/quality maps scale with
the sum of recursive point participation, in addition to direct-edge cursors.

Dense20,480 scopes *80,002 raw451-bit histories alone would be92,367,109,120
logical bytes (~86.024 GiB), before four-state/container overhead. Uniform runs
avoid that per-edge retention without discarding data. Irregular inputs may need
many runs and more memory; there is no user history depth, slot count or RAM cap.

Actual simulator allocation is not made infallible by a signed-index guard.
Current queue push/class allocation exposes no checked allocator status here;
host-OOM recovery was not proved. Diagnostic evidence distinguishes actual
simulator failures from controlled rejection. `BW_MON_TEST_FAULTS` enables a
one-shot `inject_growth_failure(scope,resource)` only in test builds. It rejects a
semantic next growth with scope, resource, physical/original time, edge/sequence
and current/requested use. Ordinary builds expose neither that API nor a capacity
configuration. Tests cover every storage owner and final-reachable failure;
injection does not prove nominal-scale correctness or real malloc recovery.

Fatal startup/configuration handling latches terminal failure before `$fatal`, which may return from a VCS final block. Runtime numeric/storage failures instead warn and quarantine their typed owner and dependent ancestors. Active consumer responsibilities are cancelled independently of frozen ancestry; a healthy sibling keeps its unread data until its own ACK. Same-time completion diagnostics run in the writable coordinator after posted grants and producer certificates. Read-only contract observers only inspect settled state. The unified final report responsibility audit is a separate follow-up.

The runner hashes its options, absolute sources, recursive RTL headers, explicit
fixture units and each case's compile defines. Fault builds cannot reuse an
ordinary-build binary. `expect_log` and `expect_counts` distinguish unavailable
metrics, valid zero and duplicate final summaries.

## Reproduction and scope

`python3 tests/run.py` runs the full current contract suite; named cases select a
slice. `history_trace_{ns,cycle}` checks an independently worked17-edge,2-point/
group table with W3/S2, zero/sizeX/validX, partial cuts, reset and changed/stopped
clock. `variation_pending_retention` checks six raw transfers followed by30000ns
quiet and unresolved K60000, selecting exactly the three owned windows. The4096-edge `transport_growth` scene now preserves the original byte/event/window/quality literals with synchronous original-time delivery. `transport_capacity4096` separately verifies4096 real distinct-edge records retained in one source at the storage component seam. `transport_same_time_pressure4096` verifies4096 aggregate frames plus two controls held at one timestamp by real group consumers over controlled producers; its cancellation counterpart checks release of only the failed consumer's responsibilities. These are distinct scopes, not a relabelled positive-time backlog success. Arithmetic/MAX/D16, raw numeric/policy/query/core failures
and the `storage_failure_*` owner matrix have their exact expectations in
`tests/cases.json`; existing hierarchy/completion/alignment/epoch tests are retained.

Public-point resource pilots preserve exact source snapshots, driver hashes,
commands, configuration, GNU time-v compile/simulation RSS and all online result
checks. Their one/64-point profiles are engineering evidence only. They do not
claim common/max topology, maximum-duration matrix, FSDB/human review or all
possible traffic fitting a fixed host. Those later acceptance workloads remain
required; wall-time observations are not acceptance thresholds.

Measured NS pilot provenance (all profiles use actual public points, W40000/S1,
2GHz/64B, no groups/cfg/waves, N3/span2/K1/Q4; GNU time-v primary RSS):

| Frozen source | Metric implementation | 64 points40us | Same64 binary100ns | Duration RSS difference |
| --- | --- | --- | --- | --- |
| d9fad43 | before24 interval metrics | 1,039,484 KiB | 118,080 KiB | 921,404 KiB |
| ead7b23 | post24, before26 | 122,668 KiB | 120,064 KiB | 2,604 KiB |
| 6750c72 | post24/26 with numeric/retention27 | 124,172 KiB | 122,428 KiB | 1,744 KiB |

The final frozen profile checked2,560,000 windows and80,000 raw edges per point,
finishing at exactly40us. Its one-point40us run checked40,000 windows at114,640
KiB peak. Final compile peak was350,660 KiB, separately measured. Observed wall
seconds were58.985 for64-point long,2.545 for matched short and3.053 for1-point
long; these schedule observations impose no speed threshold. The source snapshots
also differ in metric/report/validation code, so the whole cross-version RSS
change is not attributed solely to one change. Matched duration differences still
include allocator/runtime effects and are not per-record size measurements.

Exact source hashes, generated driver hashes, options, every final public row,
commands, compile/simulation logs and time-v measurements are retained under the
corresponding resource-pilot directories in the ticket evidence. These profiles
prove their declared checks only; neither a common/max hierarchy workload nor a
full scale/history matrix was run by this pilot.

Final numeric/storage integration validation on2026-10-25: **408/408 contract
cases passed** across **160 compiled tops**, including all321 incoming integration
cases and87 numeric/storage additions. The full invocation returned0 without
infrastructure retries. All final compile logs have no Warning-/Error- diagnostics;
all current ROOT/runner/defines/source/recursive-header/fixture fingerprints match,
and each runtime log is newer than its current compilation stamp. Exact error,
expected-log and expected-count predicates were independently reapplied to all
408 captured outputs. `git diff --check` passed. Current integration ae5edb5 was
merged before final validation; this proof includes the full group-analysis and
reporting composition.
