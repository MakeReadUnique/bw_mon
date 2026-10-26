# Current-source compatibility proof

This separate, serial campaign ran the complete existing **427 component cases /
168 tops** and **42 public E2E scenes** on reviewed source
`816464ac673a508616d12a5cd535c6771164f879`. All passed. It is additional spec-wide
compatibility evidence, outside the revised quick/full acceptance time budgets;
it does not substitute for maximum-topology, fragmented-history or M4/H6 evidence.

The source contains the reviewed Ready-wait split and the disabled-by-default
scheduling/telemetry hooks. Relative to the preceding production proof, fifteen
production files are unchanged; the point, group and package files changed.
The archived freeze records all eighteen exact hashes. Ordinary component/E2E
runs did not enable `BW_MON_TEST_SCHEDULING`; the separate revised quick/MAX
fixtures exercise that test hook.

## Verify without simulation

```sh
python3 tests/review/compatibility/verify.py
python3 tests/review/compatibility/verify.py --current-source
python3 tests/review/compatibility/test_verify.py
```

These commands require Python3.6+ and a POSIX environment, but no VCS, Verdi,
former `/tmp` worktree, installed SDK or native compiler. The regressions execute
with no simulator or Git on `PATH`. `--current-source` additionally checks the
274 archived production, component-fixture/config and E2E-oracle inputs against
this checkout; `--source-root PATH` selects another checkout. The separately
recorded orchestration helper from the actual run is retained as provenance,
not confused with the subsequently improved current helper.

The verifier checks archive/member hashes, the complete case manifest, all
427 positive/expected-fatal predicates and required log patterns, all168 clean
compilations, exact source-cache digests, actual native dependency receipts and
binary/object identities. It replays the frozen independent raw/window,
episode/phase/variation and configured-performance references for all42 scenes.
Missing or duplicate results cannot qualify a smaller subset.

It then compares every original stimulus and all **672 public scope CSV files**
with the fresh run, byte for byte, and compares every public final report packet.
Only the cfg file's absolute path is normalized; values, identities, quality,
conclusions and record counts remain exact. Cross-scope log interleaving is not
an ordering contract; per-scope sequences and the final summary barrier are
checked separately. Negative regressions include missing component/scoped data,
changed historical CSV content, removed phase packets and variation packets after
the final summary, even after consistently
rebuilding archive hashes.

## Actual evidence

| Result | Observed |
| --- | ---: |
| Component cases / compiled tops |427 /168 |
| E2E scenes / public scope CSV files |42 /672 |
| Raw records / core receipts |161472 /161472 |
| Published windows |86375 |
| Episode / phase / variation records |518 /1350 /1868 |
| Old-to-fresh numerical/packet differences |0 |
| Fresh FSDB files / total bytes |42 /7899475 |
| Component stage elapsed / peak RSS |2339.518s /352508KiB |
| E2E stage elapsed / peak RSS |169.434s /352456KiB |

Stage elapsed times include cold builds, simulation and the original runner
checks. External equality/source audits and portable archive replay are separate.
Both stages ran serially under the shared qualification lock. These are observations of this
additional broad campaign, not the revised <=30-minute suite or a monitor
slowdown percentage. Expected performance FAIL/WARNING conclusions and expected
core fatal tests are checked behavior; they are not compatibility failures.

`proof.tar.gz` contains2550 original evidence files. Its extracted layout is:

- `campaign/`: source before/after inventories, original source snapshot,
  reviewed production freeze, tool/native identities, driver and completion
  manifests, component/E2E verification and post-run E2E build identities.
- `components/` and `component-records/`: original serial console/time receipts,
  every test/compile log, cache stamps, actual native dependency files and
  simulator/native-object SHA256 receipts.
- `fresh/<scene>/`: actual stimulus, cfg, all16 public CSVs, full logs,
  independent reference/comparison tables, compile/native/source receipts and
  the fresh `waves.fsdb` for every scene.
- `historical/<scene>/`: unchanged original trace/cfg/source/command/reference
  receipts used for the equality audit, plus the original global review ledger.

SDK/system headers and executable binaries are not vendored. The receipt records
the actual source plus50 transitive SDK/system header hashes, optimized native
compiler options, actual VCS dependency files, compiler identities and
before/after stability. Simulator/native-object hashes were read from the
completed builds; the portable audit validates their receipts and does not claim
to recompute absent executable bytes. Original absolute build paths are retained
as reproduction context; verification does not access those paths.

The raw external run is retained at
`/tmp/bw-mon-spec13-revised.uX6BKM/compatibility-evidence/`; its fresh FSDBs are
also in `fresh-e2e/`. The repository archive includes those FSDBs, so it has no
external-artifact dependency. Original commands are `python3 tests/run.py
--no-cache` and `python3 tests/acceptance/run.py --all`, from an isolated checkout
of the recorded revision with the recorded VCS/Verdi tool setup.

## Human review boundary

The [original approved waveforms and review ledger](../../../artifacts/acceptance/review.json)
remain unchanged. Every fresh scene explicitly retains `human_review=PENDING`.
No new screenshot, UI inspection or human attestation was fabricated or copied
onto the fresh runs. Exact public-result equality supports the documented
compatibility claim; approval remains bound only to the original named artifacts
and intervals.
