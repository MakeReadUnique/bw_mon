# History matrix evidence

The [current nominal campaign checkpoint](final-campaign/README.md) records six
completed/audited final-source40us profiles out of twelve required new rows,
with614016000 raw receipts and307132157 new windows, zero differences. Its full
matrix explicitly leaves six running/prepared MAX profiles unaccepted. This is a
partial checkpoint, not ticket31 completion.

Root per-profile bundles retain completed verified historical profiles. Each bundle includes the
original input/cfg/generatedSV, expected/actual final scope rows, empty diffs,
verification, full bounded final/progress logs, exact command/tool/source/options
manifest, separate compiler/simulator time-v and launch context. Source snapshots
are grouped by the consumed commit and preserve every hashed source/header/helper.
No simulator binaries or vendor libraries are archived.

The separate dated [final-source preparation](final-preparation/README.md) preserves
eleven literal checks and six actual small public tracers on runtime56127495,
plus twelve nominal receipts that were unlaunched at preparation time. It is not a passed nominal
matrix. Its verifier rehydrates the consumed source and original artifacts
without VCS or former temporary worktrees; older root bundles stay qualified by
their historical source. Operator-superseded records remain separately labelled.

```sh
python3 tests/scale/history_evidence/archive.py verify
python3 tests/scale/history_evidence/archive.py pack RUN_MANIFEST --source-root FROZEN_SOURCE
```

Hashes cover both compressed and original files. The verifier independently
recompares every final reference/actual field/count, with exact integer/flag
comparison and1e-9+1e-12*abs(expected) binary64 tolerance. Numerical pass is separate
from legitimate performance WARNING/FAIL. Running, queued, failed or smoke profiles
are not recorded as passed matrix cells. Existing29/30 evidence remains qualified
by its original source/configuration; all required unrun combinations stay open.
