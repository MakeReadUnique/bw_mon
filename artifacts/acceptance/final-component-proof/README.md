# Final steady validity repair: component proof

This separate campaign records the exact merged runtime
`467b722cde3ea00e8eb8ed0e97dcc72d4dc67aa9` (production milestone
`56127495f597d215003000356ac3b5387cc809a1`). It preserves historical424-case
scheduling evidence and waveform assets with their original source identities.
It does not close scale qualification or actual human T6 review.

The full427-case/168-top campaign uses the repository's unchanged VCS runner in
four shards grouped by distinct tops. Every original runtime/compile log,
source/fixture/cfg byte, shard command/result, source before/after fingerprint,
cache stamp, actual native dependency file and checked simulator/native-object
hash is retained in `components-467b722.tar.gz`. The manifest and verifier check
archive/member SHA256s and all positive/expected-fatal predicates, required
patterns/counts, clean compiles and exact cache digests. The archive stores
header hashes as provenance; vendor/system header text, binaries and libraries are omitted.

```sh
python3 tests/review/evidence/verify.py
python3 tests/review/evidence/verify.py --current-source
```

Portable inspection requires Python3.6+ and no VCS, old `/tmp` directory or SDK.
`--current-source` also requires all18 current production RTL/C/header files to
match the consumed files. The optional `--source-root` selects a different checkout.
`--current-native-headers` additionally checks the locally installed50 header and
compiler hashes plus recorded mtime/ctime; it requires that original installation.
Extracting `source/` reproduces the exact fixture tree for `python3 tests/run.py`
with the documented VCS installation/native SDK available. Relative cfg arguments
remain interpreted from each `.build/tests/<top>` working directory.

The new public point/group regression establishes a normally completed episode
with an unknown first boundary and a later independently complete final steady
interval. The interval contains70B over7.25ns and eight10GB/s window samples:
steady BW9.655172413793103GB/s fails its20GB/s bound while sigma0 passes. The known
start control gives the same phase results; uncertain last activity keeps final
selection unavailable. Existing reset/truncation/quality and foreign-episode
eligibility tests are included. The genuine RED/GREEN and independent eight-case
regression logs are preserved separately under `targeted/` with their original
source context; current acceptance is the full427 campaign, not the old RED.

The only runtime tool warning is the intentional `report_unreadable` STASKW_CO
for the absent cfg file. Performance FAIL/WARNING test outcomes are independently
checked expected behavior. They are not component test failures.

The original `freeze.json` remains byte-identical: its plain `gcc -M -I SDK`
pre-run query recorded49 headers. That was not the full dependency set for the
actual VCS command, which also passed `-O`. The separate
`native/postrun-supplement/` records the original optimized gcc argv/line/hash for
all168 compile logs and dependency-only replays of both normal and fault-defined
commands. Both replays include50 headers; the additional file is
`/usr/include/bits/stdlib-bsearch.h`. Original VCS `.d` files remain unchanged and
list only the source and2SDK headers; the complete system-header inventory is
kept separately.

This is explicitly a post-run metadata supplement. All50 header hashes and
compiler identity were measured then; the original49 hashes still match. Every
header/compiler mtime and ctime predates the actual campaign start, and hashes/
stat records stayed identical across the dependency replays. The verifier checks
recorded gcc lines against compile logs, raw full-M output against header sets,
original49 equality, all168 command/native-object/binary links and file-stability
metadata. The archive records byte preservation of every original runtime,
compile, cache, native `.d`, source, freeze and final campaign record against the
previous proof. No427 simulation or native object was rebuilt for this metadata
correction, and no pre-run50-header inventory is claimed.
