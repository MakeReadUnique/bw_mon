# Steady NS reading checkpoint

Automated reference check PASS; **human review PENDING**. Agent image inspection
is recorded separately in capture-manifest.json. This checkpoint is not the full
T6 scene bundle or an attestation for later variants.

Twelve real DUT wrappers, one module-type bind, all three protocols, fixed and
adapter-decoded dynamic bytes; four groups with independent full analysis. Common
clock first edge0.5ns, period0.5ns; data64B/edge before120ns, then idle. W10ns/S1ns,
N3/span2ns/K2/Q12ns and explicit fit/hint parameters are in scene.sv/commands.json.
Expected rates follow64B/0.5ns and the unique4/4/8/6 member sets; p10/p11 are free.
All checked snapshots are full, byte/event complete, positive denominator and
without member reset. Small arithmetic tolerance1e-10GB/s is not a performance
cfg tolerance. This first checkpoint has no performance cfg.

|Scope|Interval|Expected GB/s|Actual GB/s|Difference|
|---|---|---:|---:|---:|
|p0|[92,102)ns|128|128|0|
|p1|[92,102)ns|128|128|0|
|p2|[92,102)ns|128|128|0|
|p3|[92,102)ns|128|128|0|
|p4|[92,102)ns|128|128|0|
|p5|[92,102)ns|128|128|0|
|p6|[92,102)ns|128|128|0|
|p7|[92,102)ns|128|128|0|
|p8|[92,102)ns|128|128|0|
|p9|[92,102)ns|128|128|0|
|p10|[92,102)ns|128|128|0|
|p11|[92,102)ns|128|128|0|
|die0|[92,102)ns|512|512|0|
|die1|[92,102)ns|512|512|0|
|all_dmc|[92,102)ns|1024|1024|0|
|mixed|[92,102)ns|768|768|0|

Open the original [FSDB](waves.fsdb) with [open.sh](open.sh) from a machine with
Verdi and X11. [overview.sav](overview.sav) uses relative FSDB references and fixed
public paths. The [fresh1500x850 screenshot](overview.png) uses numeric real rows,
not interpolated analog curves; cursor102.000001ns shows [92,102)ns. Engineering
formatter rounds1024 to1.02K in the picture; the full exact real in
[comparison.json](comparison.json)/[FSDB export](fsdb-values.csv) is1024. Raw public
window bytes/bounds provide the same independent arithmetic. UI names/colors are
presentation only; no image or FSDB data was modified.

Provenance: [commands and source/header/driver hashes](commands.json),
[actual capture manifest](capture-manifest.json), [public paths](signals.json),
[simulation log](run.log), [original raw input table](stimulus.txt). Reproduce with
`python3 tests/acceptance/run.py --scene steady --basis ns`; recapture with
`python3 tests/acceptance/capture.py steady_ns --display "$DISPLAY"` using an
available X11 display. Exact local tool executable/config paths in manifests are
provenance; commands/scripts resolve source and output from their checkout.
