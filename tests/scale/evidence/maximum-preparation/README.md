# Current-source maximum preparation

This is preparation for [maximum-topology acceptance](https://github.com/MakeReadUnique/bw_mon/issues/30),
not a maximum-scale pass. All four native16384-point/4096-group/40us profiles
remain on hold for the current common-scale gate and resource admission.

Tested commit `1508f8f6f03ae03768f107ce0cd472182c9b6654`, tree
`c7a3e23335666610948cc536b5aa369fe64e22fa`, merges integration `cb0aef5`.
Its18 RTL/C/header contents match the repaired `8e81839` freeze. The maximum
wrapper, literal contracts, independent reference and generator match `2d5c685`.

- Five maximum literal checks and six legacy reference checks passed.
- Four actual32-point/24-group/240ns public tracers passed under
  `+vpi -debug_access`, native C and the installed VCS SDK:107,520 raw receipts
  and5,263 windows, zero differences, controls/direct ACKs/release/report checked.
- Each graph includes depth8 and subgroup source fanout16. Compiler and runtime
  tool diagnostics were absent. Formal report WARNINGs are expected for truncated
  episodes. Exact native profile counts remain recorded in `verification.json`.

`current-tracers-1508f8f.tar.gz` contains immutable consumed sources, generated
fixtures, complete configurations, SDK header path/hash provenance, per-scope
expected/actual/diff data, compile/runtime logs and receipts, independent native
input manifests and the preparation summary. It excludes binaries and vendor
SDK headers. Per-process GNUtime-v and observed process-family peaks remain
separate. Small tracer measurements do not establish maximum memory or speed.

`superseded-2d5c685-records.tar.gz` preserves original manifests/logs/receipts for
one confirmed license-service shutdown and four operator-stopped old-source
partials. `classification.json` explains each attempt. No attempt was passed or
classified as a capacity failure. Full original build assets remain at the
recorded external paths; this archive does not rewrite their source provenance.

Archive and every member SHA256 are in `verification.json`. To verify these
portable records without VCS, and optionally match current runtime/harness files:

```sh
python3 tests/scale/evidence/maximum-preparation/verify.py --current-source
```

The original commands were:

```sh
python3 tests/scale/test_maximum.py -v
python3 tests/scale/test_reference.py -v
python3 -u tests/scale/maximum.py max-tracer-ns max-tracer-cycle max-tracer-unknown max-tracer-reset --output-root /tmp/bw-mon-spec13/max-topology-30-current
```
