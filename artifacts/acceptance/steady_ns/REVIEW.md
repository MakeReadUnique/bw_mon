# Steady NS review entry

Automated original-input checks PASS. **Human review PENDING.** Agent image
inspection is separate. This is one scene in the [complete42-scene index](../INDEX.md).

T4 at2GHz/64B, W10ns/S1ns, first edge0.5ns: every point including p10/p11 measures
128GB/s, die0/die1 each512, all_dmc1024 and mixed768. Snapshot[92,102)ns has
1280B/20events per point and10240B/160events for all_dmc; full/byte/event quality
is known, with no reset coverage. Source/receipt/window/episode/phase/variance and
configured performance checks are independently validated.

[Fresh real1500x850 Verdi image](overview.png) · [original FSDB](waves.fsdb) ·
[expected/actual tables](expected-actual.md) · [public view](overview.sav) ·
[all-scope independent reference](reference.json) · [source/input/config hashes](commands.json).

`./open.sh overview` opens the portable original waveform from this directory.
Scientific10 numeric display exposes exact1024 and integer bytes/bounds separately.
No data or raster was modified. The [trace archive](trace.tar.gz) contains original
raw input, CSV, compilation/runtime/capture logs. Actual source/tool paths recorded
inside are provenance; no former worktree/build is required to inspect the FSDB.

The intentional performance goal160GB/s with5% tolerance requires152, so measured
128 is a genuine nonfatal FAIL. The scene continues through later windows and its
one final summary. This performance result is expected test behavior, not a failed
automation check. Human review is not supplied by automated PASS or agent inspection.
