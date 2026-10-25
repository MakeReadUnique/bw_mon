# Scheduling repair evidence

These files record source
`8e81839423ab7db335365a5e577e25b2ebe5dcb0`, tree
`4dffbead003115374813b4bdfcd685f8df50fe66`. They verify the same-time reset,
hint and publication-handoff repair. They do not close nominal-scale, waveform
or human-review acceptance.

```sh
python3 tests/scheduling/evidence/verify.py
python3 tests/scheduling/evidence/verify.py --current-source
```

The first command checks the recorded, version-qualified archives. The optional
second command also requires current production RTL/C/headers to match the
consumed source. `verification.json` records compressed/member SHA256s.

| Archive | Contents |
| --- | --- |
|components-8e81839.tar.gz |424 runtime logs,167 clean compile logs/cache stamps, complete consumed RTL/C/header/fixture/cfg source, four-shard commands/results and before/after source hashes |
|minimum-options-8e81839.tar.gz |Two isolated real public tops; mixed four-state/group-only and known pulse modes; three runs with `+vpi -debug_access`; exact commands, copied sources, logs and binary hashes |
|tracer-8e81839.tar.gz |Three-point public protocol slice through child/parent, intentional reference-error RED and positive run; copied sources, commands and resource records with the scale compiler options |
|original-source-red.tar.gz |Original production5cf489b (RTL equal8de785c), six public modes and their logs; ordinary controls pass, program/ReNBA reset, hint and phase modes fail |

The full campaign finished2026-10-25T13:30:53Z with424/424 cases across167 tops;
all recorded source/fixture hashes stayed unchanged. Independent post-run audit
rechecked each positive/negative marker, required log/count predicate, current
cache digest and runtime-after-compile ordering. Compiler diagnostics were clean.
`report_unreadable` intentionally emits VCS STASKW_CO for its absent cfg and the
monitor's FILE_UNREADABLE warning; it is the sole recorded runtime tool warning.

For replay, extract the component archive and run `python3 source/tests/run.py`
with the documented VCS SDK available. The original-source RED archive has its
own old runner/source/fixture subset; its expected outcome is3/6 passing controls,
with the three specified failing modes. A `$fatal` can return process status0 on
this VCS version, so verdicts inspect diagnostics and explicit success markers.

The exact-budget case instantiates two real points and two groups with W40000/S1,
checks160,000 publications plus a late ReNBA edge and all direct ACKs, and ends at
40000000000fs through a read-only deferred verdict. It has no positive-time drain.
Its small topology is a temporal-boundary regression. Old408-case/common/max/FSDB
recordings retain their original source labels; current-source nominal and
human-waveform evidence must be produced separately.
