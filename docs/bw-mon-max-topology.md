# Maximum-topology correctness and resources

The fixed profiles in `tests/scale/maximum.py` reuse the public-module generator,
independent leaf-set/clock reference and every-receipt/window checker documented
in [the scale harness](bw-mon-scale.md). They address [maximum topology
acceptance](https://github.com/MakeReadUnique/bw_mon/issues/30). Native profiles
always request 16,384 points, 4,096 group owners and exactly 40us; the wrapper has
no reduced-count or reduced-duration override.

```sh
python3 tests/scale/test_reference.py
python3 tests/scale/test_maximum.py
python3 tests/scale/maximum.py max-tracer-ns max-tracer-cycle max-tracer-unknown max-tracer-reset
python3 tests/scale/maximum.py max-ns max-cycle max-ns-short-unknown max-cycle-short-reset --output-root /path/to/evidence
```

Every native profile uses the same independently checked, recursively disjoint
graph. Every group has 16 direct members, giving 65,536 edges. Groups0 through7
form a depth-eight chain: group0 has 16 points; each next level adds 15 fresh
points. Group7 therefore contains 121 recursive points. Fifteen other groups
include point0, so that point has exactly sixteen direct parents. Remaining
groups use bounded point reuse. Point16383 is ungrouped and remains included in
the expected total and every local check. Recursive cardinalities are16 for4089
groups, then31/46/61/76/91/106/121 for the seven upper chain groups. The graph
SHA256 is `736a6660a63a4596fe2d41e45e241c4024c98c05957c13f297b31f0b67a7f2a3`.

The manifests retain every typed direct edge and every independent recursive leaf
set. A group's registered counts are observations to compare with this input,
never oracle inputs. Points keep the default full hierarchy identity
`tb_bw_scale.points[N].slot.mon`; group IDs are explicitly `scale.gN`, owned at
`tb_bw_scale.groups[N].slot.mon`. Explicit Group IDs are required by the public
module. Every scope is an actual public module, with the unified setup and
automatic collectors; the test never manually forwards or acknowledges frames.

| Native profile | Basis, W/S | Intervention | Expected window checks |
| --- | --- | --- | ---: |
|max-ns |ns100/10 |none |81,920,000 |
|max-cycle |cycle200/20 |none |81,899,520 |
|max-ns-short-unknown |ns10/10 |p0 sizeX at100.25ns |81,920,000 |
|max-cycle-short-reset |cycle20/20 |p0 reset[100.1,101.1)ns |81,899,519 |

All four profiles specify2GHz, first edge0.25ns, final edge39999.75ns and end40000ns
exactly:80,000 raw receipts per scope,1,638,400,000 checks per native profile.
There is no post-budget drain. The complementary short/mid rows cover both
bases and quality/reset at maximum counts; dense and full-scene history rows
belong to the separate history-matrix acceptance. A failed or unrun row stays
unverified.

The inherited fixed feature settings enable episodes/phases on every point and
group, with Q30ns/60cycles, N3, span20ns/40cycles, K4, explicit hysteresis/fit/trend
coefficients, and all12 report rules per typed scope. Point protocols alternate
valid-only/valid-ready/credit by index modulo3; even indexes use dynamic64B and
odd indexes fixed64B. Supported backpressure/shortage hints are enabled at
4ns/8cycles. Credit capacity and known initial balance are16 with NEXT_CYCLE
returns every edge. Unsupported hints remain disabled. Full inputs, thresholds,
tool options and source/header hashes are retained in each run's manifest.

Unknown size keeps the known event, removes64B from the known subtotal and
marks only byte completeness. Exactly23 groups contain p0, including all eight
chain levels and its fifteen independent parents. Known reset removes two p0
events, restarts only its local statistics and leaves ancestor schedules/history
intact. Ancestors receive all original-time frames/controls and retain member
reset coverage until exact expiry. The independent final rows and every-result
checks distinguish cumulative raw traffic, local epoch totals and window counts.

Waves are off. The repaired runtime requires `rtl/bw_slot_settlement.c`, `+vpi`
and at least `-debug_access`. The runner passes the installed VCS SDK include
directory to the C compiler, snapshots every local RTL/C/header and harness
source before compilation, and fingerprints their contents. It uses
`-debug_access` without `+all`; removing debug access completely is unsupported
for this runtime. See [the scheduling contract](bw-mon-scheduling.md). SDK header
paths and SHA256 values are retained with the preparation evidence, without
redistributing vendor headers. GNUtime-v compiler/simulator peaks and sampled
process-family peaks are recorded separately; no memory or wall-time acceptance
cap is imposed.

## Current evidence

The final-source preparation at `31ce03c16af62911985ee9191da51c7534396ebf`
merges integration `467b722c`. Its18 runtime RTL/C/local-header hashes exactly
match the reviewed production milestone `56127495`. Five maximum and six legacy
reference contracts passed, followed by four serial32-point/24-group/240ns
public tracers:107,520 raw receipts and5,263 windows, zero differences.
The maximum wrapper, fixed profiles, independent reference and generator retain
their original inputs and nominal expected counts above.

| Final-source tracer | Window checks | Compiler peak KiB | Simulator peak KiB |
| --- | ---: | ---: | ---: |
| max-tracer-ns |1,344 |350,680 |126,216 |
| max-tracer-cycle |1,288 |350,676 |125,668 |
| max-tracer-unknown |1,344 |350,676 |125,304 |
| max-tracer-reset |1,287 |350,676 |125,832 |

Each small graph includes a depth-eight path and sixteen direct consumers of a
subgroup. Every receipt, window, quality flag, control, direct-member ACK and
release, hint and final report stream was checked. Separate recorded-data audits
also found zero differences. Performance WARNINGs reflect truncated traffic;
they do not replace correctness checks or establish maximum resource use.

The [final-source preparation archive](../tests/scale/evidence/maximum-final-preparation/README.md)
retains the26 consumed sources, complete original/generated inputs, cfg,
per-scope expected/actual/differences, native build/cache and runtime evidence.
Its portable verifier regenerates the independent inputs/reference and checks
all original hashes and final streams without VCS or former temporary paths:

```sh
python3 tests/scale/evidence/maximum-final-preparation/verify.py --current-source
```

Fresh output roots include the profile, source, compiler options/tool, native
header and installed-link-input identity. Full GCC dependency discovery uses
actual native `-w -pipe -fPIC -O` flags:50 headers, including2SDK and48system
headers. Plain `gcc -M` finds49; optimization additionally includes
`bits/stdlib-bsearch.h`. The original VCS dependency file intentionally omits
system headers, so the full inventory and original twoSDK dependency entries
are preserved separately. Native object/binary and before/after source/header/
link-input hashes accompany the exact compile/link commands. Vendor header text
and binaries are not redistributed.

At the archived preparation checkpoint, all four nominal inputs were
**PREPARED_NOT_LAUNCHED**. Those immutable receipts keep their original status;
the archive supplies small preparation evidence only. After final-runtime COMMON
qualification and staged resource admission, `max-ns`, `max-cycle`,
`max-ns-short-unknown` and `max-cycle-short-reset` are now **SIMULATION_RUNNING**
(observed 2026-10-25 17:26 UTC) from immutable builder
`31ce03c16af62911985ee9191da51c7534396ebf`. All four have reached Ready and produced
progress without a recorded fatal/mismatch at this observation. No full profile
has completed acceptance, and the maximum-topology ticket remains **OPEN**.

The full jobs retain the original16,384-point/4,096-group/40us inputs and expected
counts. Each creates20,480 native reset observer contexts plus the coalesced
pending settlement callback. Ongoing progress does not replace the required
final raw/window/quality/ACK/report comparisons or measured final resource record.

The archived resource plan covers four topology MAX rows and six later history
MAX rows. Prior8e-source partial kernels used about1.6GiB each; current full-run
peak/resource qualification remains incomplete. Four topology rows have since
been admitted using recorded live host/RSS/progress checks. Further admission
requires fresh observations. These scheduling choices impose no product memory
or wall-time acceptance cap.

## Completing the current qualification

The original monitor ends at `FOUR_FULL_RUNNERS_VERIFIED_ARCHIVE_AUDIT_PENDING`.
The separate `tests/scale/qualify_maximum.py` workflow supplies the remaining
recorded-data audit and portable archive. Its [continuation receipt](../tests/scale/evidence/maximum-qualification/continuation.json)
pins the four original manifests, launch receipts, immutable source, native
identities and fixed expected counts. That receipt is a running checkpoint;
it contains no nominal pass.

To check once, use a fresh archive destination:

```sh
python3 tests/scale/qualify_maximum.py archive \
  --campaign /tmp/bw-mon-spec13-resume/max30-final-complete-campaign \
  --launcher /tmp/bw-mon-spec13-resume/max30-final-launch.py \
  --current-source . \
  --monitor /tmp/bw-mon-spec13-resume/max30-monitor.py \
  --output /tmp/bw-mon-spec13-oct26/max30/full-nominal-proof
```

Exit status 2 means some original simulations remain pending, and no archive is created.
Exit status 1 means qualification was rejected. `watch` accepts the same arguments plus
`--status /tmp/bw-mon-spec13-oct26/max30/qualification-status.json` and
`--poll-seconds 30`; it waits for the existing four runners, then audits them
serially. A missing runner before recorded verification is an error. Completion
requires the actual 40 us results, exact nominal counts, and successful independent
replay. The workflow never changes a ticket or the PR; its final status remains
`ticket_complete=false` pending the independent merger and final review.

For each profile the workflow regenerates the complete original input, cfg,
reference and public SV from its 26 consumed source files, rechecks the final
formal stream in an isolated copy, and retains the original evidence bytes.
It checks all 18 current production hashes; actual native compile/link commands;
the optimized 50-header inventory and original two-SDK-header dependency file; installed
link-input hashes; tool versions; original native-object/binary identity; and
both GNU time-v and process-family RSS. Post-run tool executable hashes are
explicitly supplemental measurements, not invented pre-launch hashes.

The archive includes source snapshots, complete per-profile records, original
launch recipes/receipts, native audits and monitor snapshots. A portable replay
must pass before its temporary directory becomes the final archive destination.
Across the four required profiles the fixed totals are 6,553,600,000 checked raw
receipts, 327,639,039 publications and 81,921 episode finals, with zero differences.
These are required counts, not currently completed counts.

After a genuine full archive is available, its bundled verifier works without
VCS, SDKs or the original temporary paths:

```sh
python3 /path/to/full-nominal-proof/verify.py verify /path/to/full-nominal-proof --current-source .
python3 tests/scale/test_qualify_maximum.py
```

The workflow was exercised using the four genuine archived small preparations:
107,520 raw checks and 5,263 publications, zero differences. Each native audit
and portable replay passed, including replay with an empty tool search path.
The tests reject promoting a tracer or a mislabeled launch receipt into nominal
acceptance and verify that recorded-data replay preserves the originals. The
pending gate was also checked against the four actual running full profiles.
These validate the qualification workflow; full nominal acceptance still waits
for the original simulations and their final audits.

## Historical preparation and superseded attempts

The earlier [maximum preparation](../tests/scale/evidence/maximum-preparation/README.md)
retains its genuine11 literal checks and four small tracers on the8e runtime.
It is historical after the561 production review fix; its `--current-source`
comparison is expected to reject a changed runtime. Its former native profile
plans were never full nominal passes.

Two8e-production MAX runs from frozen builder `7e9e441` were later launched and
explicitly stopped when the final-statistics review fix required a new production
source. Their sources, original manifests/logs and stop receipts are preserved
in the final-source preparation archive. The classification is
`OPERATOR_SUPERSEDED_REVIEW_SOURCE_FIX`, neither PASS nor a correctness/capacity
failure. Their interrupted manifests are retained byte-for-byte.

Still older2d5-source attempts include a license-service interruption and four
partials superseded by the scheduling fix; these remain in the historical
preparation archive. Neither those partials nor their older no-debug probe
establish support for omitting the final runtime's native/debug dependencies.
