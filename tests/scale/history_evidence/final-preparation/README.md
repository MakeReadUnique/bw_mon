# Final-source history preparation

**Small preparation passed; none of the twelve nominal history profiles has
launched from this frozen builder.** These results qualify the driver and public
integration path for a later admitted campaign, not ticket31 or nominal scale.

The clean detached builder is commit
`04ce34a85e45dab273a650e2e1131410f56885e8`. Its eighteen production RTL/C/local
headers exactly match runtime `56127495f597d215003000356ac3b5387cc809a1`, including
the review fix for independently valid final steady results. The history
extensions to the shared scenario/generator/runner remain present. Four original
common29 profiles regenerate byte-identical original inputs, cfg, expected CSV
and all three generated SV files against the final common29 builder; see
`legacy-equivalence.json`.

Actual VCS executions were serial, with waves off, 32 points/eight groups and
240ns. Every row has forty public scope results. Baselines have480 real frames
per scope; the explicitly shortened control-clock variants have450. No fake
edge or additional positive-time drain is used.

| Small public profile | Checked raw receipts | Checked new windows | Differences |
| --- | ---: | ---: | ---: |
| NS10/S1 |19200 |9600 |0 |
| Cycle20/S2 |19200 |9560 |0 |
| NS40000/S1 |19200 |9600 |0 |
| Cycle80000/S1 |19200 |19160 |0 |
| NS7/S3 control/clock |18000 |3199 |0 |
| Cycle7/S3 control/clock |18000 |5959 |0 |
| Total |112800 |57078 |0 |

Five history and six legacy reference contracts also passed. The verifier
rehydrates the actual consumed sources and original artifacts in private temporary
directories, regenerates input/config/reference/SV, checks every final scope and
formal stream, and independently checks the short baseline's N3/K4 steady
boundaries. Long small tracers correctly lack enough full-window phase evidence.
Compiler peak RSS was350676–350684KiB; simulator peak122816–127216KiB. These are
small-run observations, not nominal memory results or acceptance caps.

Each original launch receipt fingerprints all26 consumed sources, actual VCS
options, VCS/gcc/g++ binaries and versions, and installed native link inputs.
The native dependency query uses the actual GCC options, including `-O`, and
freezes50 headers: two SDK and48 system headers. The postrun audit compares each
actual recorded native/link command and all hashes. Original VCS `.d` files
intentionally list the C source and two SDK headers while omitting system
headers; they are retained unchanged alongside the separate full dependency
inventory. Vendor and system header contents are not copied into this repository.

Run the portable recorded-data audit from a checkout, without VCS or the former
absolute source/build paths:

```sh
python3 tests/scale/history_evidence/final-preparation/verify.py --current-source
```

`nominal/` preserves twelve **PREPARED_NOT_LAUNCHED** receipts and complete build
fingerprints. Fixed profile counts, W/S, original topology and exact40us endpoint
are recorded in `verification.json`. In the W80000 cycle row only79999 complete
cycles exist, so a warmup final result remains the correct expected behavior.
The separate common/max middle-window evidence must actually complete on a
compatible production source before being reused by the final matrix.

The local future launcher is
`/tmp/bw-mon-spec13-resume/history31-final-launch.py`; every selected output root
is fresh and includes its complete build fingerprint. The COMMON-only scheduler
is prepared at `/tmp/bw-mon-spec13-resume/history31-final-common-scheduler.py`.
It admits at most two COMMON jobs, no MAX history jobs, and requires both explicit
root admission and a closed common29 blocker. It stops new admission after an
actual failure while retaining evidence. It has not been started. The exact
recipes are archived here for provenance; their former absolute paths are not
dependencies of the portable verifier.

`operator-superseded-839b5f4.tar.gz` preserves the previous source's two interrupted
history attempts, their original manifests/logs/source, and the verified operator
stop receipt. They are classified **OPERATOR_SUPERSEDED_REVIEW_SOURCE_FIX**,
neither passed acceptance nor correctness/resource failures. Older completed
history evidence remains in the parent directory with its historical source
qualification. No old pass or human attestation is transferred to this builder.
