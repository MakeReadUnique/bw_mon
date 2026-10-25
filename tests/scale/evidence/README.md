# Recorded common-scale evidence

The original profile directories below retain the historical source074c771
campaign. The [repaired-source campaign](repaired-source-3bba72c/README.md) contains
four fresh full-scale40us results on production8e818394; its source, profiles,
resource measurements and results are separate. `verify.py` checks both campaigns;
`--current-source` additionally matches the repaired production files to this
checkout. No original historical bundle was replaced.

Each profile directory contains deterministic-gzip copies of original run files.
`bundle.json` records their uncompressed/compressed SHA256s and the original
source commit/manifest. Source, input, generated SystemVerilog, cfg, reference,
actual scope rows, differences, final records and resource logs remain separate.
The compressed logs contain bounded progress/final records, not one row per
raw event or window. No simulator binaries or vendor libraries are stored here.

Reproduce with the public runner described in [the scale guide](../../../docs/bw-mon-scale.md).
The source tree named in each original manifest is immutable; later evidence/docs
commits do not imply a different simulator run. Original absolute paths and UTC
start/end/exit details are preserved as historical command evidence. Decompress
files before checking the original manifest's uncompressed hashes. The companion
bundle hashes cover their repository copies directly.

All actual profiles finish at40us exactly. Continuous-flow truncation legitimately
produces unavailable performance evidence and WARNING; numerical correctness is
established by every raw/window online check plus reference/actual/diff files.
Concurrency is recorded explicitly and is not a standalone timing benchmark.

The consumed21-file source/driver snapshot is included in `source-074c771/` with
its own source index. `results.json` summarizes actual counts and separate
compiler/simulator peaks; `concurrency.json` and resource samples preserve host
context. Check every compressed/original/source hash and final reference row with:

```sh
python3 tests/scale/evidence/verify.py
```

`package.py REPO ORIGINAL_RUN_MANIFEST [DESTINATION]` preserves original run files;
`audit-recorded.py REPO ORIGINAL_RUN_MANIFEST` checks the uncompressed original
run/build directories and canonical constant-flow phase boundary120/confirm150
(orcycle+0.25ns). These are evidence tools, separate from the simulation runner.
The supplemental audit's script hash is retained in its output. Source and
generated snapshots permit reconstruction independently of the original absolute
paths or later repository revisions.

The recorded audit honors `manifest.source_snapshot` when the current runner
stores consumed files under `build/source/`. Original manifests without that
field retain their earlier `build/rtl/` interpretation. The current archive also
retains the actual native dependency and compile-success records. These tooling
changes do not rerun simulations or alter original result files.
