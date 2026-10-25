# Final-source maximum preparation

This records small preparation for [maximum-topology acceptance](https://github.com/MakeReadUnique/bw_mon/issues/30).
It does not claim a nominal MAX pass. At this checkpoint all four final-source
16,384-point/4,096-group/40us profiles are **not launched**, pending the new common
qualification and explicit resource admission.

Tested clean source `31ce03c16af62911985ee9191da51c7534396ebf` merges integration
`467b722cde3ea00e8eb8ed0e97dcc72d4dc67aa9`. All18 production RTL/C/local-header
hashes match the reviewed `56127495f597d215003000356ac3b5387cc809a1` milestone.
The26 consumed source files, generated fixtures, full configuration/reference/
actual/difference rows, compile and simulation logs, caches and native dependency
receipts are retained here. Binaries and vendor header text are excluded.

Five maximum literal contracts and six legacy reference contracts passed.
Four public32-point/24-group/240ns tracers then ran **serially** with native C,
`+vpi -debug_access`, depth8 and subgroup fanout16:

| Profile | Raw receipts | Windows | Differences | Compiler peak KiB | Simulator peak KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| max-tracer-ns |26,880 |1,344 |0 |350,680 |126,216 |
| max-tracer-cycle |26,880 |1,288 |0 |350,676 |125,668 |
| max-tracer-unknown |26,880 |1,344 |0 |350,676 |125,304 |
| max-tracer-reset |26,880 |1,287 |0 |350,676 |125,832 |

These checks include original-time raw/window records, quality and reset,
direct-member consumption/release, hints and final formal-stream ordering. The
separate recorded-data audit found zero discrepancies in all four runs.
Performance WARNINGs correctly describe truncated episodes and do not substitute
for correctness checks. No large-scale memory or throughput conclusion follows
from these small runs.

Each output root includes a complete source/profile/tool/options/native-header/
installed-link-input fingerprint. GCC dependency discovery uses the actual
`-w -pipe -fPIC -O` native flags and records50 headers:2SDK and48system headers.
Plain `gcc -M` records49; optimization adds `bits/stdlib-bsearch.h`. VCS's own
original `.d` omits system headers, so its twoSDK entries and the separate full
dependency/hash inventory are both retained. Before/after hashes, the actual
native object/binary hashes and exact compiler/linker commands remain recorded.
All of these are provenance, not redistributed SDK contents.

`source/` and the four profile directories can be checked without VCS, SDKs or
the former absolute paths. The verifier regenerates input/configuration/reference
and public SV from the consumed source, then rechecks each final stream:

```sh
python3 tests/scale/evidence/maximum-final-preparation/verify.py --current-source
```

The `prepared-max-*.json` files freeze the four **unlaunched** nominal inputs,
counts and build identities. The original profiles and expected counts are
unchanged. Reproduction uses the public runner, fresh output roots and a full
build; the recorded `launch-recipe.py` explains the additional identity receipt.

```sh
python3 tests/scale/test_maximum.py
python3 tests/scale/test_reference.py
python3 tests/scale/maximum.py max-tracer-ns max-tracer-cycle max-tracer-unknown max-tracer-reset --force-compile --output-root /fresh/small-evidence
```

`resource-plan.json` proposes staged admission for the four topology and later
six history MAX rows. Actual prior8e-source kernels used about1.6GiB each before
being stopped; final-source nominal peak/runtime remains unknown. Host memory,
compiler activity, existing user work and actual progress must determine later
admission. There is no product memory cap or wall-time target.

`operator-superseded-7e9e441.tar.gz` preserves the two original8e-production
MAX partials, their consumed sources, logs and exact operator stop receipts.
Their manifests retain `VERIFICATION_FAILED` from interruption; the receipt
classifies them as `OPERATOR_SUPERSEDED_REVIEW_SOURCE_FIX`, neither accepted runs
nor correctness/capacity failures. Earlier8e small preparation and still older
2d5-source attempts remain in the separate historical preparation directory.
