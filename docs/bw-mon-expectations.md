# Expectation configuration and reports

Point and group metric checking implements [tickets 25](https://github.com/MakeReadUnique/bw_mon/issues/25)
and [26](https://github.com/MakeReadUnique/bw_mon/issues/26), specification D12–D13.
Integrate the ordinary point/group and setup modules, enable episode analysis with
an explicit silence threshold, and pass one scene file:

```systemverilog
bw_mon_setup setup();
bw_point_mon #(.POINT_ID("tb.port[0].bw"), .WINDOW_WIDTH(4), .UPDATE_STRIDE(1),
  .FIXED_BYTES(152), .EPISODE_ENABLE(1), .SILENCE_THRESHOLD(2)) bw
  (.clk(clk), .reset_n(reset_n), .valid(valid));
```

```text
./simv +BW_EXPECT=/path/to/scene.cfg
```

The file is read once during preparation, after registration freezes and before
the single Ready publication. Its rules survive
statistics resets. There is no hot reload. Phase-enabled scopes also run the
fixed default sustained-variation check without an expectation file. With phase
analysis disabled and no explicit rule, the summary is `STATISTICS_ONLY`.
An explicitly missing/unreadable file is
a nonfatal cfg WARNING. Enabling a target does not enable episode analysis or
choose Q; missing episode evidence produces WARNING.
An empty `+BW_EXPECT=` value warns before file I/O, and a bare `+BW_EXPECT` warns
that a path is required. Unrelated names such as `+BW_EXPECTED` do not select
expectation checking.

## Default sustained-variation check

Enabling phase analysis also enables this rule in `bw_check_report`; no extra
module, file, threshold, duration, reference-count or near-zero setting is needed.
It settles each confirmed steady platform once at its episode's final boundary.
No usable platform gives one episode WARNING; no episode gives one final scope
WARNING. Ordinary warmup and reference waiting do not produce repeated warnings.

The reference is the earliest six consecutive valid windows fully contained in
the final platform, spanning at least `min(W,5*S)` in the selected basis.
`B=sum(y)/6` is frozen and the reference rows themselves are checked. It differs
from the steady phase's raw bytes divided by duration; both are reported.
For positive B, a row exceeds the limit exactly when `abs(y-B)>0.05*B`.
Equality passes, with no epsilon, file tolerance, or positive near-zero floor.
B=0 or insufficient reference/coverage gives WARNING.

A FAIL needs at least two consecutive new valid exceedance rows whose original
logical endpoints span at least W. Alternating high/low deviations continue the
same run. Invalid evidence, an in-band row, reset or a confirmed exclusion breaks
it. Replayed snapshots/final records add neither samples nor results. Original
cycle positions govern cycle windows even when clocks stop or change frequency;
record delivery time never supplies elapsed duration. A reliable FAIL survives
later missing evidence or truncation; otherwise incomplete evidence gives WARNING.
Explicit bandwidth, time and CV targets remain independent, and their PASS cannot
overwrite this rule's FAIL. Summary priority is FAIL > WARNING > PASS > STATISTICS_ONLY.

`BW_DEFAULT_CHECK` reports typed full scope identity, epoch/episode/platform,
window basis/W/S, final platform and check boundaries, exact reference sequence
membership/count/span, B and raw steady bandwidth, absolute/relative peak
deviation, threshold, over-limit run count and longest run endpoints/count/span,
quality, conclusion and reason. Ns logical positions/spans use original fs ticks;
cycle positions/spans use original local cycle indices.

The single-platform product cases include real four-point/named-group constant
traffic and alternating ±8% traffic that remains STEADY while this check FAILs.
Cross-platform handoff and independent normal-step attribution are delivered by
the following ownership work; these single-platform results do not establish
that contract. Pending raw publications and original seven-row recognition
support remain lossless until episode settlement for that work.

## File grammar and complete supported keys

```ini
# These are scene targets, not product defaults.
[point tb.port[0].bw]
e2e_bw_min_gbps = 160
e2e_bw_rel_tol_pct = 5

[point "another.# interface[7]"] # Quoting preserves a literal # and whitespace.
e2e_bw_min_gbps = 160
e2e_bw_max_gbps = 200
e2e_bw_abs_tol_gbps = 2
e2e_bw_rel_tol_pct = 5
```

Names, keys, scope types and complete IDs are case sensitive. Blank lines and
surrounding whitespace are ignored. `#` starts a comment outside double quotes.
Unquoted generated IDs retain all hierarchy and array brackets: the section
ends at its final `]`, not at an array subscript. Quoted IDs preserve leading
and trailing whitespace and support `\"`, `\\`, `\n`, `\r` and `\t` escapes.
An empty identity, malformed quotes or unknown escape makes the header invalid.
There are no wildcard, inheritance or procedural sequence targets. A repeated
section refers to the same exact scope, including its already-seen keys.

The complete supported table has12 metrics and48 keys. Each row supports an
inclusive lower bound, upper bound, absolute tolerance in the metric's unit and
relative tolerance as a percentage of each bound. Bounds default to absent;
tolerances default to0. No unconfigured metric participates in comparisons.

| Metric / definition | Lower key | Upper key | Absolute tolerance key | Relative tolerance key |
| --- | --- | --- | --- | --- |
| Episode raw bytes / actual duration | `e2e_bw_min_gbps` | `e2e_bw_max_gbps` | `e2e_bw_abs_tol_gbps` | `e2e_bw_rel_tol_pct` |
| Final last steady raw bytes / actual duration | `steady_bw_min_gbps` | `steady_bw_max_gbps` | `steady_bw_abs_tol_gbps` | `steady_bw_rel_tol_pct` |
| Every confirmed ramp fragment duration | `ramp_time_min_ns` | `ramp_time_max_ns` | `ramp_time_abs_tol_ns` | `ramp_time_rel_tol_pct` |
| Every confirmed fall fragment duration | `fall_time_min_ns` | `fall_time_max_ns` | `fall_time_abs_tol_ns` | `fall_time_rel_tol_pct` |
| Last steady minimum qualified window value | `steady_window_min_min_gbps` | `steady_window_min_max_gbps` | `steady_window_min_abs_tol_gbps` | `steady_window_min_rel_tol_pct` |
| Last steady maximum qualified window value | `steady_window_max_min_gbps` | `steady_window_max_max_gbps` | `steady_window_max_abs_tol_gbps` | `steady_window_max_rel_tol_pct` |
| Last steady population standard deviation | `steady_stddev_min_gbps` | `steady_stddev_max_gbps` | `steady_stddev_abs_tol_gbps` | `steady_stddev_rel_tol_pct` |
| Last steady coefficient of variation | `steady_cv_min_pct` | `steady_cv_max_pct` | `steady_cv_abs_tol_pct` | `steady_cv_rel_tol_pct` |
| Episode minimum qualified window value | `episode_window_min_min_gbps` | `episode_window_min_max_gbps` | `episode_window_min_abs_tol_gbps` | `episode_window_min_rel_tol_pct` |
| Episode maximum qualified window value | `episode_window_max_min_gbps` | `episode_window_max_max_gbps` | `episode_window_max_abs_tol_gbps` | `episode_window_max_rel_tol_pct` |
| Episode population standard deviation | `episode_stddev_min_gbps` | `episode_stddev_max_gbps` | `episode_stddev_abs_tol_gbps` | `episode_stddev_rel_tol_pct` |
| Episode coefficient of variation | `episode_cv_min_pct` | `episode_cv_max_pct` | `episode_cv_abs_tol_pct` | `episode_cv_rel_tol_pct` |

`gbps` means decimal GB/s, `ns` means physical nanoseconds even in cycle mode,
and `pct` means percent. Absolute CV tolerance is in **percentage points**;
relative CV tolerance is a percentage of the configured CV target. At least one
bound is required; tolerance-only entries warn/disable only that metric rule.

The long `steady_window_min_min_gbps` spelling deliberately distinguishes the
selected window minimum from the comparison direction. Window mean is context
(`mean_gbps`), with no target keys. Neither that mean nor phase-fit RMS replaces
raw steady bandwidth or population standard deviation.

Groups use `[group FULL_ID]` and their own12 independent rules. Point and group
namespaces remain distinct even for identical ID strings. Targets do not inherit,
sum, scale with active membership or change across resets/episodes. For example:

```ini
[point shared]
e2e_bw_min_gbps=40
[group shared]
e2e_bw_min_gbps=100
[group parent]
e2e_bw_min_gbps=120
steady_bw_min_gbps=120
ramp_time_max_ns=6
episode_cv_max_pct=10
```

All values must be nonnegative finite binary64 numbers. Decimal forms such as
`10`, `+10.`, `.5` and `1e+2` are accepted; signs on exponents are allowed. Negative
numbers (including `-0`), units/suffixes, hexadecimal, underscores, incomplete
exponents, NaN and infinity are rejected. Validation scans the complete token,
checks its decimal magnitude against the exact maximum finite binary64 value,
then converts it. This prevents VCS `%f` prefix acceptance and its silent
overflow-to-DBL_MAX clamp. A nonzero token that underflows to zero is invalid;
finite subnormal values are supported. Exact zero remains zero with any legal
exponent spelling. A nonfinite expanded tolerance/bound is also invalid.

For lower L, upper U, absolute A and relative R percent, the permitted range is:

```text
lower = L - (A + abs(L) * R / 100)
upper = U + (A + abs(U) * R / 100)
```

Both configured sides must pass. Equal boundaries pass; the lower expansion
may legitimately be negative and is not clamped to zero. L must not exceed U.
Comparisons use the actual binary64 values without a hidden acceptance epsilon;
logs retain 17 significant decimal digits. Thus L=160/R=5 expands to 152: actual
152 passes while 151.99 and 128 fail. L=160/U=200/A=2/R=5 expands to [150,212].

## Error isolation and evidence

An unknown key is warned and discarded while recognized rules remain usable.
A duplicate key, invalid number, conflicting bounds or overflow disables only
that scope's affected metric rule. Duplicates across repeated sections are detected
and never overwrite a rule silently. A malformed/unregistered/unsupported header
quarantines subsequent keys until a valid header, so they cannot modify the
preceding scope. Missing `=` for a recognized key disables its affected rule;
other malformed lines warn and are discarded. File read failure disables all
checking from that file. Every cfg warning records file, line, scope type/ID,
key and reason. Already-disabled rules do not generate another missing-evidence
warning at observation end.

Each reliable ramp/fall fragment settles independently when its final interval is
known. A later gap, reset or truncation never removes that earlier conclusion.
When an episode has no confirmed ramp/fall, its configured time rule warns once
for that episode. Steady rules settle only from the completed episode's final
last-steady selection; intermediate plateaus do not compare as representatives.
An unresolved selection warns even when an earlier complete plateau exists.
No confirmed steady does not prevent independent complete e2e or episode variation.

Min/max need at least1 qualified sample; sigma needs2; CV needs2 and a positive
window mean. Final interval/coverage must be known. Warmup and known foreign
residue are normal exclusions; unknown qualified coverage is unavailable rather
than silently deleting a sample. Zero-mean CV is `ZERO_MEAN`; insufficient sigma
is `TOO_FEW_SAMPLES`; no samples is `NO_QUALIFIED_SAMPLES`. Complete zero raw BW
and zero sigma are valid measurements. Each metric branches on its own validity
and reason before reading numeric storage: raw byte failure can coexist with
valid duration/window variation. Known member reset coverage is metadata and does
not invalidate complete group metrics or reduce their original target.

A formally comparable e2e requires normal episode completion, known first,
last and real tail-cycle boundaries, complete raw bytes, and a known positive
duration. A steady phase is unnecessary. A complete zero-byte episode is a
measured zero and can pass a zero lower bound. No episode is `NO_EPISODE`;
unknown boundaries/bytes, reset interruption and observation truncation retain
distinct evidence reasons. Unavailable values are logged as `UNAVAILABLE` and
are never compared as zero. A recovered later window does not repair an older
incomplete episode. Known member reset coverage is independent metadata.

`BW_CHECK` records are nonfatal PASS, FAIL or WARNING. Logs retain typed identity,
statistics epoch, episode and final sequence, metric/unit, [first,tail) interval,
actual availability/value, raw counts and independent quality, configured bounds
and tolerances, expanded bounds, cfg source lines, conclusion and reason.
`BW_PHASE` and `BW_EPISODE` remain the raw final-statistics streams.
Variation checks also retain sample count, first/last publication/span, window
basis/W/S, window mean and independent warmup/foreign/unknown/denominator exclusions.
Last-steady checks retain the original selected phase identity/result sequence
while their result sequence identifies the final episode selecting it. Hint logs and counters stay
separate from these performance counts.

## Synchronous result and finalization contracts

`bw_mon_setup` owns one `bw_check_report_pkg::bw_check_report` object. Compile
`bw_mon_pkg.sv` first and `bw_check_report.sv` before `bw_mon_setup.sv`. The report
owner contains parsing, immutable rules, comparison/evidence logic and counters.
The monitor package contains the dedicated abstract transport handle and types;
it holds no report rules, check counters or comparison arithmetic.

```systemverilog
emit_phase_result(string scope_id, bw_phase_result_t result);
emit_episode_result(string scope_id, bw_episode_result_t result);
bw_report_summary_t snapshot = check_report_summary();
report_scope_done(bw_scope_t kind, string scope_id, bw_u64_t stats_epoch=0);
```

The identity string and immutable static phase/episode payloads are copied by value.
Delivery is synchronous, including multiple results in one time slot and in
`final`; no toggle pulse can coalesce results. Final identities include typed
scope, statistics epoch, episode and lifetime final `result_seq`. Each scope's
phase and episode final streams have separate lifetime sequence
high-water marks; replays at or below their own high-water mark do not settle or
count again. Phase delivery precedes its final episode, so missing-time fallback
cannot race a later phase. Each configured metric produces one conclusion per
applicable final record. The same targets apply to every episode/fragment.
Zero-sequence snapshots do not settle. Window sequences are never final-result
identities. Reset does not rewind final sequences or clear previous FAILs.

Ready freezes expected participants using the controlled
`registered_scope_count(kind)` / `registered_scope_id(kind,index)` registry
queries. Querying before Ready or with an invalid index is a core error. After
flushing all remaining final records, each registered scope's core calls
`report_scope_done` once. Repeated calls and unregistered component-analysis cores
do not alter the participant count. For a scope without any episode, each enabled
rule warns once with NO_EPISODE
(already settled phase times are retained). The last participant settles missing
rules
and prints exactly one summary after all scope results. There is no independently
scheduled report `final` block and no extra integrator action. Final phase/episode
record
submission honors `core_failure_seen`; final settlement and scope completion use
`core_failure_pending()` to include unresolved deferred core errors. Deferred
fatal actions are read-only because VCS forbids latch writes in Postponed;
their candidate facts are updated in Active. Candidates cancelled by later
same-slot arrivals never suppress valid runtime records or hint hits.
Finalization rejects
an observation beyond the common immutable 40us budget before emitting results.
Core errors remain fatal and do not become performance WARNINGs.

The summary snapshot contains `pass_count`, `fail_count`, `warning_count`,
`scopes_done`, `scopes_expected`, `finalized` and `status`:

| Priority | Status | Condition |
| --- | --- | --- |
| 1 | `BW_REPORT_FAIL` / `FAIL` | At least one failed comparison |
| 2 | `BW_REPORT_WARNING` / `WARNING` | No FAIL, at least one cfg/evidence warning |
| 3 | `BW_REPORT_PASS` / `PASS` | At least one comparison, all passed, no warning |
| 4 | `BW_REPORT_STATISTICS_ONLY` / `STATISTICS_ONLY` | No comparison and no warning |

Each configured metric on an applicable final record has one conclusion. The global `warning_count` includes
each cfg diagnostic and unavailable-evidence conclusion; disabled rules are not
recounted as absent episodes. `finalized` becomes true only at the all-scope
barrier. A snapshot before that is provisional. The `BW_SUMMARY` log includes
separate counts and completed/expected participant counts.

## Reproduction

The real VCS regressions include raw repeated plateaus whose final steady raw20/30
passes while the episode CV44.4878 fails, typed mixed point/group identities,
child statistics reset with uninterrupted parent1200B/10ns, known member reset
with unscaled group116GB/s FAIL, independent unknown-byte/variation evidence,
zero/one/no-sample distinctions, all48 keys, per-rule malformed numeric isolation,
separate phase/episode replays and continuation. They also include raw100ns episodes with 15,200/15,199/12,800 B,
raw range endpoints 15,000/21,200 B and outside values 14,999/21,201 B, complete
zero and incomplete/no-episode distinctions, duplicate final records and later
PASS after FAIL, both point declaration orders during final truncation, numeric
range/grammar rejection, malformed-file isolation and the final time budget.

```sh
python3 tests/run.py report_e2e_boundary report_e2e_below report_e2e_low
python3 tests/run.py report_e2e_range_lower report_e2e_range_upper report_e2e_range_below report_e2e_range_above
python3 tests/run.py report_quality report_records report_records_later_pass
python3 tests/run.py report_cfg_suffix report_cfg_overflow report_cfg_conflict report_identity
python3 tests/run.py report_final_forward report_final_reverse report_final_budget
python3 tests/run.py report_metrics_repeated_full report_metrics_all report_metrics_mixed
python3 tests/run.py report_group_full_ns report_group_full_cycle report_group_repeat_ns
python3 tests/run.py report_metrics_zero report_metrics_quality report_metrics_independent report_metrics_interrupted
python3 tests/run.py
```

Counts, identities, sequences, times and flags compare exactly. Raw bandwidth
arithmetic assertions use a separate 1e-10 GB/s numerical tolerance for binary64
rounding; performance target comparisons use only the cfg's explicit tolerance.
`tests/cases.json` retains complete fixture paths, independent expected log
values and exact log-count checks. Test success can correctly contain performance
FAIL or WARNING and continuing traffic; it does not require performance PASS.
