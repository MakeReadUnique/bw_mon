# Expectation configuration and reports

Single-point e2e checking implements [ticket 25](https://github.com/MakeReadUnique/bw_mon/issues/25)
and specification D13. Integrate the ordinary point and setup modules, enable
episode analysis with an explicit silence threshold, and pass one scene file:

```systemverilog
bw_mon_setup #(.EXPECTED_POINT_COUNT(1)) setup();
bw_point_mon #(.POINT_ID("tb.port[0].bw"), .WINDOW_WIDTH(4), .UPDATE_STRIDE(1),
  .FIXED_BYTES(152), .EPISODE_ENABLE(1), .SILENCE_THRESHOLD(2)) bw
  (.clk(clk), .reset_n(reset_n), .valid(valid));
```

```text
./simv +BW_EXPECT=/path/to/scene.cfg
```

The file is read once when registration freezes at Ready. Its rules survive
statistics resets. There is no hot reload. With no file, statistics continue
and the summary is `STATISTICS_ONLY`. An explicitly missing/unreadable file is
a nonfatal cfg WARNING. Enabling a target does not enable episode analysis or
choose Q; missing episode evidence produces WARNING.
An empty `+BW_EXPECT=` value warns before file I/O, and a bare `+BW_EXPECT` warns
that a path is required. Unrelated names such as `+BW_EXPECTED` do not select
expectation checking.

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

The full supported key set for this delivery is:

| Key | Meaning | Unit | Default |
| --- | --- | --- | --- |
| `e2e_bw_min_gbps` | Inclusive lower target | decimal GB/s | Absent: no lower bound |
| `e2e_bw_max_gbps` | Inclusive upper target | decimal GB/s | Absent: no upper bound |
| `e2e_bw_abs_tol_gbps` | Absolute tolerance added on each configured side | decimal GB/s | 0 |
| `e2e_bw_rel_tol_pct` | Relative tolerance of each side's own target | percent | 0 |

At least one bound is required for a comparison. Tolerance-only entries warn
and disable that scope's e2e rule. Unconfigured metrics continue to be measured.
Stage, variation and group targets are subsequent extensions; unsupported keys
and `[group ...]` sections currently warn. Group sections never apply to a point
with a matching string ID.

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
that scope's affected e2e rule. Duplicates across repeated sections are detected
and never overwrite a rule silently. A malformed/unregistered/unsupported header
quarantines subsequent keys until a valid header, so they cannot modify the
preceding scope. Missing `=` for a recognized key disables its affected rule;
other malformed lines warn and are discarded. File read failure disables all
checking from that file. Every cfg warning records file, line, scope type/ID,
key and reason. Already-disabled rules do not generate another missing-evidence
warning at observation end.

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
`BW_EPISODE` remains the raw final-statistics stream. Hint logs and counters stay
separate from these performance counts.

## Synchronous result and finalization contracts

`bw_mon_setup` owns one `bw_check_report_pkg::bw_check_report` object. Compile
`bw_mon_pkg.sv` first and `bw_check_report.sv` before `bw_mon_setup.sv`. The report
owner contains parsing, immutable rules, comparison/evidence logic and counters.
The monitor package contains the dedicated abstract transport handle and types;
it holds no report rules, check counters or comparison arithmetic.

```systemverilog
emit_episode_result(string scope_id, bw_episode_result_t result);
bw_report_summary_t snapshot = check_report_summary();
report_scope_done(bw_scope_t kind, string scope_id, bw_u64_t stats_epoch=0);
```

The identity string and immutable static episode payload are copied by value.
Delivery is synchronous, including multiple results in one time slot and in
`final`; no toggle pulse can coalesce results. Final identities include typed
scope, statistics epoch, episode and lifetime final `result_seq`. Each scope's
final stream is ordered by that lifetime sequence; replays at or below its high
water mark do not settle or count again. Window sequences are never final-result
identities. Reset does not rewind final sequences or clear previous FAILs.

Ready freezes expected participants using the controlled
`registered_scope_count(kind)` / `registered_scope_id(kind,index)` registry
queries. Querying before Ready or with an invalid index is a core error. After
flushing all remaining final records, each registered scope's core calls
`report_scope_done` once. Repeated calls and unregistered component-analysis cores
do not alter the participant count. The last participant settles missing rules
and prints exactly one summary after all scope results. There is no independently
scheduled report `final` block and no extra integrator action. Both final record
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

Each final metric record has one conclusion. The global `warning_count` includes
each cfg diagnostic and unavailable-evidence conclusion; disabled rules are not
recounted as absent episodes. `finalized` becomes true only at the all-scope
barrier. A snapshot before that is provisional. The `BW_SUMMARY` log includes
separate counts and completed/expected participant counts.

## Reproduction

The real VCS regressions include raw 100ns episodes with 15,200/15,199/12,800 B,
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
python3 tests/run.py
```

Counts, identities, sequences, times and flags compare exactly. Raw bandwidth
arithmetic assertions use a separate 1e-10 GB/s numerical tolerance for binary64
rounding; performance target comparisons use only the cfg's explicit tolerance.
`tests/cases.json` retains complete fixture paths, independent expected log
values and exact log-count checks. Test success can correctly contain performance
FAIL or WARNING and continuing traffic; it does not require performance PASS.
