#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")"
view_dir=$PWD
export BW_ANALOG_VIEW="${1:-start_stop_ns}"
fsdb=$(python3 - "$BW_ANALOG_VIEW" <<'PY'
import json, sys
with open('views.json') as stream:
    views = json.load(stream)['views']
if sys.argv[1] not in views:
    sys.exit('Choose a view: ' + ', '.join(views))
print(views[sys.argv[1]]['fsdb'])
PY
)
test -f "$fsdb"
view_work=$(mktemp -d "${TMPDIR:-/tmp}/bw-analog-open.XXXXXX")
cp -- novas.rc "$view_work/novas.rc"
cd -- "$view_work"
exec verdi -nWave -play "$view_dir/open-view.tcl"
