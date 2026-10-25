# Partial nominal history campaign

**PARTIAL:2 of12 required new nominal profiles are completed and independently
audited.** The other ten rows are not accepted. This checkpoint is dated
2026-10-25 17:19:55 UTC; it is not the final ticket31 or parent-spec acceptance.
The [machine-readable matrix](completion-matrix.json) retains every fixed target,
input, enabled feature, expected count and actual completion state separately.
Running/prepared rows have no verified result or bundle.

Both completed profiles ran the original1024-point/256-group, two-level,
no-cross-group-reuse topology for exactly40us, with80000 actual2GHz sampling
edges,64B per point/edge, three protocols, fixed/dynamic policies, credit/hints,
episode/phase and all12 configured metric families. Waveforms were off.

| Completed nominal profile | W/S | Checked raw receipts | Checked new windows | Differences | Simulator peak RSS,KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| `history-common-ns-short-dense` |10ns/1ns |102400000 |51200000 |0 |284984 |
| `history-common-cycle-short-dense` |20cycles/2cycles |102400000 |51198720 |0 |280856 |
| Total | |204800000 |102398720 |0 | |

Each supplies1280 exact reference/actual final scope rows,1280 episode finals,
1280 phase finals and15360 independently checked WARNING conclusions. Continuous
traffic is truncated at the actual observation endpoint with an unknown next
edge/tail; a numerical backing zero is never compared as valid e2e. The warnings
are expected evidence outcomes, not failed correctness tests. The independent
audit also checks the constant-flow steady candidate/confirmation at12/15ns
(cycle12.25/15.25ns), original count snapshots and final stream identities.

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
```

At the recorded checkpoint, COMMON long NS/cycle and MAX long NS/cycle were
running; the two COMMON control/clock and four remaining MAX rows were prepared.
The W80000 cycle case retains its exact real-edge semantics; no extra edge or
positive-time drain may be added to manufacture a full window. The existing
final-source common29 middle-window/quality results are separately linked and
do not add to these twelve new rows. MAX30 middle/short topology rows are still
running and cannot yet be reused as accepted evidence.

All three owned controllers were alive and their actual code/state/admission
receipts were checked: COMMON history cap2, MAX history cap2 and MAX30 cap4,
global heavy cap6. Source/failure-stop gates and the explicit root native/start
staging override remain active; no elapsed-time cap increase or new admission
was made by this archival work. `controller-checkpoint.json` describes that
dated observation, not a promise about live processes after checkout.

The older completed-source bundles, six-small-tracer preparation and operator-
superseded runtime8e attempts remain intact in their separate archives. None of
their passes or states is promoted into this nominal checkpoint. Background jobs
continue under their existing controllers while the remaining matrix is pending.
