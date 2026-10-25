# History matrix evidence

Only completed verified profiles are archived here. Each bundle includes the
original input/cfg/generatedSV, expected/actual final scope rows, empty diffs,
verification, full bounded final/progress logs, exact command/tool/source/options
manifest, separate compiler/simulator time-v and launch context. Source snapshots
are grouped by the consumed commit and preserve every hashed source/header/helper.
No simulator binaries or vendor libraries are archived.

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
