#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")"
exec verdi -nWave -ssf waves.fsdb -play open-view.tcl
