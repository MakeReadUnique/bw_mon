# Partial nominal history campaign

**PARTIAL:6 of12 required new nominal profiles are completed and independently
audited.** All six COMMON rows pass; the six MAX rows are not accepted. This
checkpoint is dated2026-10-26 07:11:59 UTC; it is not the final ticket31 or
parent-spec acceptance.
The [machine-readable matrix](completion-matrix.json) retains every fixed target,
input, enabled feature, expected count and actual completion state separately.
Running/prepared rows have no verified result or bundle.

All six completed profiles ran the original1024-point/256-group, two-level,
no-cross-group-reuse topology for exactly40us. The four dense baseline profiles
retain80000 actual2GHz sampling edges; the two control/clock profiles retain
79850 real edges, the original1GHz interval and legal clock stop. Every profile
uses64B per known point transfer, three protocols, fixed/dynamic policies,
credit/hints, episode/phase and all12 configured metric families. Waveforms were off.

| Completed nominal profile | W/S | Checked raw receipts | Checked new windows | Differences | Simulator peak RSS,KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| `history-common-ns-short-dense` |10ns/1ns |102400000 |51200000 |0 |284984 |
| `history-common-cycle-short-dense` |20cycles/2cycles |102400000 |51198720 |0 |280856 |
| `history-common-ns-long-dense` |40000ns/1ns |102400000 |51200000 |0 |286812 |
| `history-common-cycle-long-dense` |80000cycles/1cycle |102400000 |102398720 |0 |254784 |
| `history-common-ns-control-clock` |7ns/3ns |102208000 |17066239 |0 |270948 |
| `history-common-cycle-control-clock` |7cycles/3cycles |102208000 |34068478 |0 |267840 |
| Total | |614016000 |307132157 |0 | |

Each supplies1280 exact reference/actual final scope rows. Each dense row has1280
episode finals and15360 independently checked WARNING conclusions; each
control/clock row has1281 episode finals and15372 WARNING conclusions. Each short
dense row has1280 phase finals, each long row has zero, and the NS/cycle
control-clock rows have2564/3844. Continuous
traffic is truncated at the actual observation endpoint with an unknown next
edge/tail; a numerical backing zero is never compared as valid e2e. The warnings
are expected evidence outcomes, not failed correctness tests. The independent
audit also checks the short rows' constant-flow steady candidate/confirmation
at12/15ns (cycle12.25/15.25ns), original count snapshots and final stream identities.

The long NS row first reaches its only full publication at the exact40us end:
point0's [0,40000ns) window contains5120000B/80000events, full/known/valid at128GB/s.
The long cycle row has79999 publications per scope and79999 complete cycles;
its last [0.25,39999.75ns) window contains5119936B/79999events and remains
warmup/full0/window-valid0, although its known rate is128GB/s/64Bcycle. Raw
totals still include80000 transfers/5120000B. No fake next edge or positive-time
drain manufactures a full W80000 result. Both long rows end with
`tail_known=0`, `status=4`/TRUNCATED, `e2e_valid=0` and
`reason=OBSERVATION_TRUNCATED` in every scope. The valid NS window does not supply
the missing episode tail. Only one full NS sample and no full cycle sample are
available, so neither long row produces a confirmed phase. Actual and canonical
reference rows and all1280 episode packets per row are cross-checked in
`long-window-contracts.json` and the portable verifier.

The control/clock runs preserve p0's unknown-size transfer at100.25ns and group0's
statistics-only reset at300.1–301.1ns. The group's raw/source epoch remains0 while
its local statistics epoch becomes1; all79850 raw receipts continue upstream,
with no physical point-reset coverage. At40us group0 contains25359360B after its
local reset, and its32-point parent retains163532736B, including the earlier
unknown64B subtraction. Recovered complete windows do not repair the old
incomplete episodes. The reference and generated checker also cover the full
known-zero NS [593,600) window and cycle window [543.25,600.25) spanning the stop:
448B/57ns and64B/cycle per point. No edge is added during the pause or after40us.

The actual clean frozen driver is `04ce34a85e45dab273a650e2e1131410f56885e8`.
Its26 consumed files include all18 production RTL/C/local headers matching runtime
`56127495f597d215003000356ac3b5387cc809a1`. Original launch/compile/run commands,
tool binaries/versions, optimized GCC options, full50-header inventory, installed
native link hashes, original VCS dependency files, simulator/object fingerprints,
GNUtime-v RSS and postrun audits are preserved. System/SDK header contents and
vendor libraries are not copied. Original `.d` files omit system headers; the
separate full dependency query retains all50 hashes with actual `-O` options.

The portable verifier rehydrates the recorded source and original artifacts in
private temporary directories, regenerates input/config/reference/generated SV,
rechecks every archived scope/final stream and recomputes source/build/native/
artifact identities. It does not compile or simulate and needs no former absolute
source/build paths, VCS installation, SDK headers or live controllers:

```sh
python3 tests/scale/history_evidence/final-campaign/verify.py --current-source
python3 tests/scale/history_evidence/final-campaign/test_verify.py
```

At the recorded checkpoint, all COMMON profiles were verified/audited. MAX long
NS/cycle and MAX short NS were running; the other three MAX rows were prepared.
The W80000 cycle case retains its exact real-edge semantics; no extra edge or
positive-time drain may be added to manufacture a full window. The existing
final-source common29 middle-window/quality results are separately linked and
do not add to these twelve new rows. MAX30 middle/short topology rows are still
running and cannot yet be reused as accepted evidence.

The COMMON controller exited naturally only after all six actual results were
audited. The archive checks that final status and every completed bundle; process
exit alone never qualifies a row. A negative CLI test rejects a hash-consistent
checkpoint missing one required audit. After a fresh host review the coordinator
explicitly admitted fixed MAX history cap3 with MAX30 cap4, global heavy cap7,
retaining the3GiB host launch reserve and failure stops. This replaced only the
owned history scheduler: both existing jobs and all six prepared build identities
were preserved, and exactly the next queued NS short profile launched. Original
cap2 code/receipts and the cap3 transition/postlaunch proof are archived under
`controllers/cap3-transition/`. There is no automatic cap increase.
`controller-checkpoint.json` describes that dated observation, not a promise
about live processes after checkout.

The older completed-source bundles, six-small-tracer preparation and operator-
superseded runtime8e attempts remain intact in their separate archives. None of
their passes or states is promoted into this nominal checkpoint. Background jobs
continue under their existing controllers while the remaining matrix is pending.
The first two short-profile folders'38 original files remain byte-identical to
the previous checkpoint; their hashes are retained in `prior-short-bundle-hashes.json`.
