#!/usr/bin/env python3
"""Pull real FSDB signals into nWave and save its untouched analog screenshot."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def resize(display, log):
    env = dict(os.environ, DISPLAY=display)
    tree = subprocess.check_output(['xwininfo', '-root', '-tree'], env=env,
                                   universal_newlines=True)
    candidates = [line for line in tree.splitlines()
                  if 'nwave' in line.lower() and '"' in line
                  and '<Verdi:nWave>' not in line and 'No File Opened' not in line]
    assert len(candidates) == 1, tree
    xid = int(re.search(r'0x[0-9a-f]+', candidates[0]).group(), 16)
    subprocess.check_call(['xprop', '-id', hex(xid), '-remove', 'WM_NORMAL_HINTS'],
                          env=env, stdout=log, stderr=log)
    lib = ctypes.CDLL('libX11.so.6')
    lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
    lib.XOpenDisplay.restype = ctypes.c_void_p
    lib.XMoveResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                                     ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
    lib.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.XCloseDisplay.argtypes = [ctypes.c_void_p]
    connection = lib.XOpenDisplay(display.encode())
    assert connection
    try:
        lib.XMoveResizeWindow(connection, xid, 10, 10, 1660, 900)
        lib.XSync(connection, 0)
    finally:
        lib.XCloseDisplay(connection)


def capture(case, display):
    out = HERE / 'evidence' / case
    work = ROOT / '.build/cfg-group-verdi-probe' / ('view-' + case)
    work.mkdir(exist_ok=True)
    fsdb = out / 'waves.fsdb'
    original_sha = sha(fsdb)
    mapping = json.loads((out / 'mapping.json').read_text())
    selected = 'g1' if case == 'second' else 'g2'
    base = mapping[selected]
    fields = ['group_id', 'active', 'bandwidth_gbps', 'result_seq', 'window_bytes',
              'window_full', 'bytes_complete', 'probe_state']
    paths = [base + '/' + field for field in fields]
    if case == 'second':
        paths += [mapping['g2'] + '/' + field for field in ['group_id', 'bandwidth_gbps']]
    ready, release = work / 'ready', work / 'release'
    for path in [ready, release, out / 'view.png']:
        if path.exists():
            path.unlink()
    raw_sav, layout = work / 'raw.sav', work / 'layout.sav'
    code = 'set w [lindex [wvGetAllWindows] 0]\n'
    code += 'wvAddSignal -win $w -clear ' + ' '.join('{' + p + '}' for p in paths) + '\n'
    code += ('wvSetPreference -win $w -hierName on -hier_signal_name on -leftalign on '
             '-partial_hier off -piecewiseLinear off -pointStyle off\n'
             'wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 3\n')
    for p in paths:
        code += 'wvSelectSignal -win $w {' + p + '}\n'
        if p.endswith('bandwidth_gbps'):
            code += ('wvBusWaveform -win $w -analog\n'
                     'wvChangeDisplayAttr -win $w -h 175 -lw 2 -c ID_CYAN5\n')
        elif p.rsplit('/', 1)[1] not in ['group_id', 'probe_state']:
            code += 'wvSetRadix -win $w -Unsigned -format Dec {' + p + '}\n'
    code += ('wvSetWindowTimeUnit -win $w 1 ns\nwvZoom -win $w 0 49\n'
             'wvZoomValue -win $w -fit\nwvSelectSignal -win $w {}\n')
    code += 'set fd [open {' + str(out / 'nwave-values.tsv') + '} w]\n'
    for at in [18.001, 32.001, 40.001]:
        code += 'wvSetCursor -win $w %s\n' % at
        for gid, p in mapping.items():
            code += 'puts $fd "%s\t%s\t[wvGetCurValueString -win $w {%s/bandwidth_gbps}]"\n' % (at, gid, p)
    code += 'close $fd\nwvSetCursor -win $w 18.001\n'
    code += 'wvSaveSignal -win $w {' + str(raw_sav) + '}\n'
    code += 'set fd [open {' + str(raw_sav) + '} r]\nset value [read $fd]\nclose $fd\n'
    code += 'regsub {viewPort[^\\n]*} $value {viewPort 10 10 1660 900 600 130} value\n'
    code += 'set fd [open {' + str(layout) + '} w]\nputs $fd $value\nclose $fd\n'
    code += 'wvRestoreSignal -win $w -appendSignals off {' + str(layout) + '}\n'
    code += 'set fd [open {' + str(ready) + '} w]\nputs $fd ready\nclose $fd\n'
    code += ('set deadline [expr {[clock seconds] + 30}]\n'
             'while {![file exists {' + str(release) + '}]} {\n'
             ' if {[clock seconds] > $deadline} {error "capture handshake timeout"}\n'
             ' after 100\n update\n}\nafter 800\nupdate\n')
    code += 'wvSaveSignal -win $w {' + str(out / 'view.sav') + '}\n'
    code += 'wvCapture -win $w -file {' + str(out / 'view.png') + '}\nwvExit\n'
    tcl = work / 'capture.tcl'
    tcl.write_text('if {[catch {\n' + code + '\n} err]} {puts stderr $err; puts stderr $errorInfo; wvExit}\n')
    command = ['verdi', '-nWave', '-ssf', str(fsdb), '-play', str(tcl)]
    process = None
    try:
        with (out / 'capture.log').open('w') as log:
            process = subprocess.Popen(command, cwd=str(work),
                env=dict(os.environ, DISPLAY=display), stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 45
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.1)
            assert ready.exists(), 'nWave handshake failed: ' + str(out / 'capture.log')
            resize(display, log)
            release.touch()
            process.wait(timeout=45)
        assert process.returncode == 0
        png = (out / 'view.png').read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (1660, 900)
        saved = (out / 'view.sav').read_text()
        rows = [line for line in saved.splitlines() if line.startswith('addSignal ')]
        assert len(rows) == len(paths), 'Some signals were not added'
        analog = [line for line in rows if line.startswith('addSignal -w analog')]
        assert len(analog) == (2 if case == 'second' else 1)
        assert all('-ds pwc' in line for line in analog)
        assert sha(fsdb) == original_sha
        expected = {18.001: {'g1': 16.0, 'g2': 22.0},
                    32.001: {'g1': 0.0, 'g2': 0.0},
                    40.001: {'g1': 8.0, 'g2': 12.0}}
        checked = []
        for line in (out / 'nwave-values.tsv').read_text().splitlines():
            at, gid, value = line.split('\t')
            actual = float(value.split('->')[-1].strip())
            wanted = expected[float(at)][gid]
            assert abs(actual - wanted) < 1e-9, (at, gid, actual, wanted)
            checked.append({'time_ns': float(at), 'group_id': gid,
                            'actual_gbps': actual, 'expected_gbps': wanted})
        assert len(checked) == 3 * len(mapping)
        # Normalize only the saved-view file path. Never edit FSDB or screenshot bytes.
        (out / 'view.sav').write_text(saved.replace(str(fsdb), 'waves.fsdb'))
        (out / 'open.tcl').write_text('set w [lindex [wvGetAllWindows] 0]\nwvRestoreSignal -win $w -appendSignals off view.sav\n')
        (out / 'capture.json').write_text(json.dumps({
            'tool': 'Verdi/nWave W-2024.09-SP1', 'command': command,
            'actual_signals': paths, 'analog_rows': len(analog), 'pixels': [1660, 900],
            'fsdb_sha256': original_sha, 'png_sha256': sha(out / 'view.png'),
            'capture_primitive': 'wvCapture', 'raster_postprocessing': False,
            'checked_nwave_cursor_values': checked,
            'agent_visual_review': 'PENDING', 'human_review': 'PENDING'}, indent=2) + '\n')
        print('Captured actual nWave', case)
    finally:
        stop(process)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--display', default=':94')
    parser.add_argument('--xvfb-bin', required=True)
    args = parser.parse_args()
    server = None
    try:
        with (HERE / 'evidence/xvfb.log').open('w') as log:
            server = subprocess.Popen([args.xvfb_bin, args.display, '-screen', '0',
                '1800x1100x24', '-nolisten', 'tcp'], stdout=log, stderr=subprocess.STDOUT)
        time.sleep(.5)
        assert server.poll() is None
        for case in ['first', 'second']:
            capture(case, args.display)
    finally:
        stop(server)


if __name__ == '__main__':
    main()
