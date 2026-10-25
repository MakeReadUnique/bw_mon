#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")"
export BW_VIEW="${1:-overview}"
exec verdi -nWave -ssf waves.fsdb -play open-view.tcl
