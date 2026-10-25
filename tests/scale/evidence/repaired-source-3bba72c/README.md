# Repaired-source common-scale evidence

Four actual prescribed common profiles completed at40us on immutable source
`3bba72c56d0edbef9f2d259fb19897ad86ba7cab`. Its18 production RTL/C/header files
match repaired runtime8e818394. All use1024 public Observation Points,256 two-level
Aggregation Groups,2GHz and the complete fixed analysis/hint/report settings in
each original input/manifest. The required NS100/10 baseline, cycle200/20,
unknown-size and point-reset variants are separate full runs. These are not
small smoke runs or relabelled historical measurements.

`results.json` records409,600,000 checked raw receipts,20,478,719 checked windows,
zero differences,5,121 episode records and5,120 phase records across all profiles.
Each profile has1280 expected/actual scope rows. Simulator peakRSS is280,492–282,320
KiB, separately measured from compiler RSS. The original logs retain correct
continuous-flow truncation WARNINGs and once-only final summaries; numerical
acceptance never substitutes a performance conclusion for the independent check.

Each `bundle.json` hashes deterministic-gzip copies of original input/config,
generatedSV, expected/actual/difference rows, verification, simulation/compile
logs, resource records, original manifest, supplementary audit, actual C compiler
dependencies and compile-success metadata. The24 consumed source/driver files
are retained in `source-3bba72c/`. Existing source074c771 evidence remains unchanged
one directory above. Original absolute paths are provenance and are not needed
to verify these copies.

`launch-receipt.json` preserves original commands and pre-run production/SDK
header hashes. `postrun-native-audit.json` records their match against the actual
build/current files after completion, including the original binary fingerprint
and native object hash. Vendor SDK header text, proprietary libraries and binary
executables are not distributed. The dependency records establish that the
recorded helper and SDK headers were compiled; their content is not a replacement
for the installed vendor SDK when rerunning simulations.

Verify all source/gzip/original/generated/native/resource hashes, regenerate all
input/reference/config/SV bytes from the archived driver and recheck every final
scope plus formal episode/phase/metric/summary stream without VCS or old/tmp paths:

```sh
python3 tests/scale/evidence/repaired-source-3bba72c/verify.py
python3 tests/scale/evidence/verify.py --current-source
```

The second command also verifies the historical campaign and requires the18
production files to match the current checkout. Recorded native SDK hashes are
retained as provenance; portable inspection does not need or read SDK headers.
Full simulation reproduction uses the public runner/configuration in
[`docs/bw-mon-scale.md`](../../../../docs/bw-mon-scale.md).

The four jobs used isolated output/build roots and overlapped on the recorded
31,857MiB/8CPU host. `postlaunch-sample-20261025T143223Z.json` adds observed resource
context. There is no memory cap, wall-time threshold or controlled speed claim.
Maximum topology and the full history/window matrix remain separate tickets.
