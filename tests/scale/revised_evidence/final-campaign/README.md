# Verified revised topology/history campaign

All four serial suites passed on frozen source `8c8f3d818979479b72fc9ed7f29b905ea9337396`.
[The formal verification](verification.json), [measured summary](summary.json) and
[artifact index](index.json) retain32 distinct real run receipts and16 immutable
native build attempts. There are no simulator binaries, native build caches or
vendor header contents in this archive. Sources, original input/reference/actual
files, differences, logs, stage receipts, native fingerprints and required
component/COMMON source closures are retained.

| Suite | Actual seconds | Limit seconds | Result |
| --- | ---: | ---: | --- |
| Daily cold | 96.596 | 300 | PASS |
| Daily cached | 25.528 | 120 | PASS |
| Complete cold | 906.636 | 1800 | PASS |
| Complete cached | 829.518 | 1800 | PASS |

Every complete suite checked21,670,663 new raw receipts and16,236,946 new
windows, with zero independent differences. Both maximum cases actually
instantiate16,384 points and4,096 groups, eight hierarchy levels,65,536 direct
edges and sixteen direct parents of subgroup0. Every direct member identity,
raw receipt, new window, typed final record and release state is checked.
M4/H6 shared cases occur once per suite, with both bases represented.
Configured performance FAIL/WARNING conclusions remain separate from correctness;
zero independent differences and complete receipts determine these test passes.

The reference host reports eight logical CPUs, Linux4.18.0-553.89.1.el8_10,
VCS W-2024.09-SP1_Full64, Python3.6.8 and GCC8.5.0. Actual host load, executable
paths/hashes, native dependency hashes, SDK identity and compiler options are
in every manifest. All cases ran serially under one qualification lock. Project
builds are cold or fingerprint-validated cached as recorded; OS caches were not
flushed. Required component compilation is invoked in both modes. Timings include
all generation, initialization, simulation, verification and process cleanup.

## Actual cases

Times below are from the complete suites. RSS is GNU time-v's simulator process
maximum in KiB, not the sum of all host memory or the monitor's allocation alone.

| Case | Cold seconds | Cached seconds | Raw checks | Window checks | Cold simulator peak KiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| topology-quick-ns | 12.749 | 3.522 | 81,920 | 40,956 | 137,900 |
| topology-quick-cycle | 11.727 | 3.729 | 81,920 | 81,754 | 140,480 |
| topology-max-ns | 336.236 | 337.919 | 10,485,760 | 5,242,876 | 2,203,100 |
| topology-max-cycle | 333.950 | 340.344 | 10,485,760 | 10,465,274 | 2,467,352 |
| history-revised-ns-seeded | 9.199 | 3.376 | 3,072 | 729 | 120,240 |
| history-revised-cycle-seeded | 9.074 | 3.014 | 3,072 | 1,023 | 120,356 |
| history-revised-ns-expiry | 9.841 | 3.653 | 24,576 | 6,144 | 124,536 |
| history-revised-cycle-expiry | 10.071 | 3.982 | 24,576 | 8,190 | 125,560 |
| history-revised-ns-deep | 17.895 | 11.872 | 240,000 | 120,000 | 165,716 |
| history-revised-cycle-deep | 20.273 | 14.692 | 240,000 | 239,997 | 156,524 |
| history-revised-pending | 9.081 | 2.733 | 7 | 30,003 | 124,556 |

The maximum NS case used1.077s generation,20.663s compilation,304.555s simulator
(including8.277s initialization), and8.965s verification in the cold suite.
The maximum cycle case used1.076s,19.959s,302.860s (including7.109s initialization)
and9.058s respectively. Remaining elapsed time is recorded orchestration.
The slowest maximum case across both modes was340.344s, below600s. The slowest
new history case was20.273s, below300s.

Complete cold/cached suites additionally include15 directed H5/H7 component
cases (83.361s/55.849s), the original frozen COMMON replay (4.138s/4.292s), and
independent regeneration/replay of every new run (35.975s/37.276s). The latter
also rejects an equal-weight two-member substitution in actual edge evidence.
No required check is hidden outside the reported suite budgets.

## Measured storage and limits of the resource conclusion

Maximum-scope NS/cycle event-history queues reached34/129 segments per scope;
sums of per-scope observed peaks were696,320/2,641,920 entries. The cycle case
retains one final event segment and one clock run per scope because its final
window includes the last active edge. NS final event histories are empty.
These legitimate statistical tails are separate from transportation: every
transport frame/control queue and every pending variation suffix is released.

The actual delayed subgroup source had five frames and two controls at the
specified unequal-consumer checkpoint; the real maximum queue depths were six
frames and two controls. Fast and slow consumer positions were203 and198, then
all caught up to204 and released the source. Growth counters also measured
20,480 registered sources,245,760 report rules,16 direct parents, six expected
edges at the paused group, and transient one-entry core frame/control queues.
Per-resource growth maxima and per-scope sampled maxima are recorded separately;
sums of individual maxima are not simultaneous global high-water marks.

The three-scope deep-history cases measured80,000 actual event segments in p0
and its group while p1 retained one exact merged run. The variable-clock expiry
case measured130 clock segments at peak,129 at end and four complete event-history
drain/regrow checkpoints per scope. The pending-suffix fixture retained30,000
samples in one exact run for each variation queue, then released both queues
and selected exactly the original three samples. These are different pressure
states, not a claim of80,000 clock segments or30,000 fragmented pending runs.

Maximum-scope simulator RSS was2,203,100/2,467,352KiB in cold NS/cycle runs;
Python verification peaked at2,781,088/2,797,228KiB because it audits the full
formal streams. Deep NS/cycle simulators peaked at165,716/156,524KiB. Compiler,
checker and simulator peaks are separate observations. No sum of these figures
is presented as a simultaneous maximum-topology/deep-history measurement, and
there is no product memory cap, event loss or approximate accounting.

## Portable replay

```sh
python3 tests/scale/revised_evidence/final-campaign/verify.py verify tests/scale/revised_evidence/final-campaign
```

The bundled verifier regenerates original inputs and references from their exact
source snapshots, checks every original artifact hash, binds case labels and
cold/hot modes to distinct receipts, reconciles child-stage and parent timing,
checks cached versus freshly executed compilation, recomputes all15 component
build-source stamps, and replays the deduplicated179-file COMMON closure.
The original six COMMON rows retain614,016,000 raw checks/307,132,157 windows and
zero differences; the old stopped/unstarted MAX rows remain incomplete.
The15 unchanged production files and three changed wrapper/test-hook files are
identified explicitly; historical results are not relabeled source-identical.

Archive creation plus its intrinsic replay took95.152s. A separate replay with
`PATH=/nonexistent` passed in82.938s using Python alone; see
[the restricted replay receipt](portable-replay.json). These packaging/audit
measurements are separate from the required recorded replay already included
in every suite budget. Absolute original paths inside receipts are provenance;
portable checks use archive-relative source and result closures.

The old four MAX40μs simulations were user-stopped and never passed. This new
matrix does not restart them or convert their identities. The actual427-case /
42-scene current-source compatibility proof is
[separate](../../../review/compatibility/README.md); prior human waveform approval
continues to describe its named historical assets, not these waveform-free scale
cases. Final PR/issue review is workflow status, separate from these completed
measurements.
