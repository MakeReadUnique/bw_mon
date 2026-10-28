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
| `report_identity` | three extra WARNINGs | Each one-transfer episode has no confirmed platform; full IDs retained |
| `report_quality` | three extra WARNINGs before final; five overall | Zero/gap/reset/active/idle each retains its own insufficient-platform result |
| `report_final_forward/reverse` | two extra WARNINGs | Two short truncated episodes have no platform; final ordering unchanged |
| `report_metrics_repeated{,_full}` | two extra WARNINGs | Final platforms have only four fully contained reference windows |
| `report_group_*` ns/cycle | five extra WARNINGs; reset adds sixth; repeat adds five | Ten-transfer episodes cannot provide six final-contained platform reference windows; reset/repeat creates independent episode identities |
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
Component fixtures do not establish recognition or normal-step ownership.

The private `bw_check_window_t` preserves original sequence, epoch/episode,
physical endpoints, logical endpoints, value and quality. Compression requires
bit-identical real values/quality plus affine sequence and all four endpoints.
`bw_phase_result_t.support_first_seq`, `support_last_seq`, `support_count`,
`support_min_gbps` and `support_max_gbps` freeze the original seven recognition
rows and envelope. Those rows remain reconstructible from the pending stream;
the latest six-fit ring is not substituted. Pending rows include undetermined
regions and are released only after terminal episode settlement. The following
ownership ticket must add independent handoff/step qualification and recropping;
current single-platform coverage makes no claim for that contract.

Runtime-disabled active scopes require the later partial-terminal hook to settle
from an actual finalized platform/cutoff and original last trusted endpoint.
Pending raw/support evidence is retained for that hook; a current fit snapshot
must never be promoted into a fabricated finalized platform. Historical settled
FAIL results survive. Normal reset/gap/truncation is covered here independently.
Formal fixed-family/scale/resource campaigns remain in their later tickets.
