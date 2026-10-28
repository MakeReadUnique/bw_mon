# Default checker contract coverage

No pre-existing test is retired. Explicit target patterns/counts remain separate
from `BW_DEFAULT_CHECK`; their individual bandwidth/time/CV decisions are retained.
The old `report_statistics_only` and `report_unrelated_plusargs` names remain for
traceability: their phase-enabled raw input now adds one default PASS. The
analysis-disabled scope in `checker_empty` retains STATISTICS_ONLY behavior.

| Existing coverage | Updated expectation | Independent input/reason |
| --- | --- | --- |
| `tb_report_e2e`, positive 100-transfer tables | one extra default PASS | Constant or one-byte table imbalance is below 5%; six contained windows exist |
| `tb_report_e2e`, zero tables | one extra WARNING | Reference is exactly zero; explicit zero bandwidth still PASSes |
| `tb_report_cfg` | two extra WARNINGs | Two one-transfer episodes have no platform; parser and explicit rule assertions unchanged |
| `report_identity` | three extra WARNINGs | Each one-transfer episode has no confirmed platform; full IDs retained |
| `report_quality` | three extra WARNINGs before final; five overall | Zero/gap/reset/active/idle each retains its own insufficient-platform result |
| `report_final_forward/reverse` | two extra WARNINGs | Two short truncated episodes have no platform; final ordering unchanged |
| `report_metrics_repeated{,_full}` | two extra WARNINGs | Final platforms have only four fully contained reference windows |
| `report_group_*` ns/cycle | five extra WARNINGs; reset adds sixth; repeat adds five | Ten-transfer episodes cannot provide six final-contained platform reference windows; reset/repeat creates independent episode identities |
| `point_historical_fail/shared_arithmetic` | retain explicit FAIL/PASS; add 2/1 default WARNINGs respectively | Real one-transfer enabled episodes cannot establish a reference, including before later disable |
| Manual explicit final-record tests | unchanged counts | Their registered points have phase analysis disabled; no implicit B is manufactured |

`checker_default_constant`, `checker_default_alternating`, and
`checker_default_explicit` drive actual protocol/clock input through four real
points, one named group, the PAIR6 recognizer and the checker. `check.py` derives
reference sequences 7..12, exact physical/selected logical boundaries, raw byte
bandwidth and default outcome from the fixed input schedule. It never selects
expected windows from product geometry. Alternating ±8% remains one STEADY
platform and FAILs; explicit bandwidth/CV targets independently PASS.

`checker_numeric_*` uses the approved immutable publication/final-record seam
for exact numeric, replay, dense stride, original logical positions and terminal
quality cases. It supplies six raw reference rows, never B or rule overrides.
Low equality catches averaging-order changes. The `expanded` fixture changes a
non-disqualifying known reset-coverage flag each row to prevent affine grouping;
its B, 5% equality, maximum and outcome must equal the compressed fixture exactly.
The real `checker_cycle_*` cases additionally change physical period from 1ns
to 2ns and include a 20ns stopped interval while holding the same cycle snapshot.
The raw byte schedule compensates for each following physical period; both typed
point/group results retain B100 and the alternating longest run spans 17 cycles.
Real `checker_default_reset/gap/truncated` cases retain a reliable earlier FAIL
when terminal quality becomes incomplete.
Component fixtures do not establish recognition or normal-step ownership. All numeric rows
are delivered together at 200ns, after their original endpoints; delivery time
adds no sustained duration. `explicit_time` independently PASSes a final-record
ramp duration while the default rule FAILs. `checker_history` drives two real
episodes and preserves earlier point/group FAILs after later PASSes.

The private `bw_check_window_t` preserves original sequence, epoch/episode,
physical endpoints, logical endpoints, value and quality. Compression requires
bit-identical real values/quality plus affine sequence and all four endpoints.
`bw_phase_result_t.support_first_seq`, `support_last_seq`, `support_count`,
`support_min_gbps` and `support_max_gbps` freeze the original seven recognition
rows and envelope. Those rows remain reconstructible from the pending stream;
the latest six-fit ring is not substituted. Pending rows include undetermined
regions and are released only after terminal episode settlement. The private phase evidence owner now qualifies final handoffs, original-seven
normal-step proofs and RAMP/FALL exclusions from these retained fields,
independently of checker reference/threshold/verdict. Final crop recomputes the
proofs and never flushes the unresolved old prefix prematurely.

Runtime-disabled active scopes require the later partial-terminal hook to settle
from an actual finalized platform/cutoff and original last trusted endpoint.
Pending raw/support evidence is retained for that hook; a current fit snapshot
must never be promoted into a fabricated finalized platform. Historical settled
FAIL results survive. Normal reset/gap/truncation is covered here independently.
Formal fixed-family/scale/resource campaigns remain in their later tickets.

`checker_disabled` and `checker_disabled_phase` reject new default evidence/phase
storage under the established test-only fault mechanism using typed scope keys.
The point first settles a reliable FAIL, then fails storage in a later episode.
Its independent same-ID group contains the healthy point and continues to PASS.
Scope-owned helpers stop before queue/receipt mutation on failure; previously
settled totals remain. Pending active evidence is retained for the later partial
terminal hook, with no fabricated platform final and no new disabled-scope PASS.

`checker_equivalence_*` compares every public default-result field exactly for
compressed/split raw receipts in the same execution at both 5% equalities and
both just-outside values. It asserts B100/threshold5 and the exact IEEE double
peak, rather than reusing stale logs or inspecting representation internals.
`checker_numeric_unknown_status` rejects an unknown final status as incomplete
quality; four-state metadata cannot be coerced into PASS.
`checker_quickstart_*` compiles the actual unchanged example input:20 transfers
of64 bytes with W10 cannot supply six platform-contained reference windows, so
its default WARNING remains beside its optional explicit e2e PASS. User-guide
summaries now describe the measured result without changing the example input.

Independent review regressions are retained as `checker_empty_immediate`,
`checker_prefix_*` and `checker_replay`. Analysis facts now enter report
preparation before Ready rather than racing its first consumer. Prefix fixtures
keep the first unknown-size transfer and all later raw bytes/times unchanged:
the later sole platform has scoped complete evidence and PASSes, while optional
explicit e2e remains WARNING. Invalid rows within its check interval and terminal
truncation still warn. `check_prefix.py` independently selects8..13 reference
sequences and the7..24.5ns final interval from that raw input.

The approved final-record replay fixture emits same-ID point/group packets,
replays each settled episode/platform with new delivery numbers100/200, then
accepts genuine next episode seq2 and a new epoch reusing episode/platform1 at
seq3. Six default and six explicit results appear exactly once. Durable bounded
watermarks use logical identities and the core's synchronous ordered immutable
final streams (epoch, then episode, then platform ID), rather than delivery
counters or a growing history map. Watermarks/receipts commit after successful
settlement and pending raw evidence is not cleared on failed attempts. Numeric
fixtures explicitly state scoped byte completeness for their valid raw streams;
whole-episode flags remain separate from scoped platform/check quality.


Cross-platform joint coverage uses the same `tb_phase_fixed` source and all four
unchanged protocol input files. `check_ownership.py` first runs the independent
raw-window/frozen-phase checker, then checks literal per-platform verdicts and
reference endpoints. Expected B/membership comes from independent raw protocol
sums and publication order. Physical ticks and actual local cycle indices are
kept distinct (the first counted edge gives prototype-relative cycle u an
explicit +1 offset). No test supplies recognizer labels through a public API.

| Adopted R2 case/repair | Product evidence |
| --- | --- |
| 100→200 bridge160→170, wait170→220, retained60→170 | `phase_fixed_continuous`; original7 supports1..7/17..23, all4 platforms PASS, RAMP/FALL remain independently attributed |
| Short pause u81..92,12rows/span11 | `phase_fixed_activity`; old FAIL, `[88,91)` WARNING, recovery PASS; actual local cycle indices82..93 due first counted edge |
| Sustained anomaly u111..156,46rows/span45ns across3short platforms | `phase_fixed_recovery`; old FAIL and late PASS, independent FALL106..111/RAMP157..164 |
| Original shorter anomaly remains PASS | unchanged case12 in `phase_fixed_recovery`; no retuning or deletion |
| STEADY and FAIL; early FAIL then later PASS | `phase_fixed_platforms`, exact original phase timelines and references |
| Qualified handoff without6reference rows | `checker_ownership_five_reference`; exact tail240ns, final platform180..240, handoff180/190, candidate refs190..230 only5 |
| Earlier130/140 anomaly retained through step170..220 | `checker_ownership_early_fail`; real point/group recognizer, old FAIL/new PASS |
| Final short platform cannot hand off | `checker_ownership_crop{,_reset,_truncated}`; actual final94..100ns, old reliable49..61ns FAIL retained |
| Final crop withdraws an otherwise valid step | `checker_ownership_records_crop` supplement at approved immutable-record seam; complete original raw rows, final225ns invalidates new220..321 handoff/support and old FAIL returns |
| Rejected gap/reset/reversed/long bridge, original7 envelope overlap | `checker_ownership_records_*` supplements; raw values/geometry supplied, never B or exemptions |
| Late reset preserves already supported earlier handoff | `checker_ownership_late_reset`; old PASS/new WARNING, no manufactured old-reference FAIL |

Frozen continuous case2 intentionally differs from the prototype's five-reference
result: its actual final phase is `[T_case+180ns,T_case+240ns+1fs)`, so the window
ending at240ns is wholly inside and six references190..240ns exist. The original
four input files, phase boundaries and the independent exact-geometry oracle are
unchanged. The exactly aligned separate public fixture establishes the adopted
five-reference WARNING behavior without rounding that1fs away.

This is focused component/public joint qualification, not the later full formal
fixed-input/scale/resource campaign. Runtime-disabled active-scope partial
terminal hooks remain with their own integration ticket.
