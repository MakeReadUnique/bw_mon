# Current runtime common-scale evidence

All four actual full COMMON profiles completed at40us on frozen source
`467b722cde3ea00e8eb8ed0e97dcc72d4dc67aa9`. Its18 production files match the final
steady-metric fix `56127495f597d215003000356ac3b5387cc809a1`; later documentation
or evidence commits are not the simulated source. Each profile uses1024 public
Observation Points,256 two-level Aggregation Groups and2GHz. Required NS100/10,
cycle200/20, unknown-size and point-reset runs keep their original complete
analysis/hint/report/activity configuration.

The actual records in `results.json` report409,600,000 checked raw receipts and
20,478,719 checked windows,5,121 episode records,5,120 phase records and zero
differences. There are1280 reference/actual rows per profile. Simulation peakRSS
is283,284–286,844KiB, separately measured from compilation. Correct continuous-flow
truncation WARNINGs and once-only final summaries are checked independently from
raw/window numerical correctness.

The24 consumed files are retained under `source-467b722/`. Each profile's
`bundle.json` hashes compressed and original bytes for input/cfg/reference/actual/
differences, all3 generatedSV files, original manifest, simulation/compile/resource
logs, supplementary audit, actual native `.d` and compile-success metadata.
Absolute paths are original provenance and are not needed for portable checks.
Historical source074c771 and source3bba72c/production8e818394 bundles remain intact.

`launch-receipt.json` preserves the actual source24+SDK2/tool/options fingerprint
and original four runner commands. `postrun-native-audit.json` links source/native
object/binary/SDK hashes to those original builds. The additional
`native-postrun-supplement/native-full-flags-supplement.json` records a **post-run**
dependency-only survey of each actual optimized gcc command. Its4 dependency
files identify50 headers, including `stdlib-bsearch.h` enabled by `-O`. The original
VCS `.d` files and SDK2 receipt remain unchanged. The50 header files and compiler
binary have mtime/ctime before the original campaign start. Their post-run hashes
and stat records remain stable across repeated surveys, and SDK2 hashes match
the original receipt. This retrospectively supplements
provenance and does not claim a pre-run50-header snapshot. No native code or
simulation was rerun for that survey; no header text, library or executable is
distributed.

Run the shared portable verifier through this campaign or the aggregate entry:

```sh
python3 tests/scale/evidence/final-runtime-467b722/verify.py --current-source
python3 tests/scale/evidence/verify.py --current-source
```

It validates original/compressed/source/generated/native/cache/resource hashes,
actual gcc lines and50-header metadata, regenerates all exact input/cfg/reference/
SV bytes from the archived driver, and rechecks all5120 final scope rows plus
complete episode/phase/metric/summary streams in temporary copies. It invokes no
VCS and reads no former build directory or installed SDK header. The aggregate
entry also checks earlier campaigns while matching only this latest runtime to
the current checkout.

The four jobs shared the31,857MiB/8CPU host with the separately recorded427-case
component campaign. `postlaunch-sample.json` records actual simulator process
families and observed RSS. There is no memory cap, elapsed-time gate or controlled
speed comparison. Maximum topology and the full history/window matrix remain
separate required acceptance work. Reproduction settings and commands are in
[`docs/bw-mon-scale.md`](../../../../docs/bw-mon-scale.md).
