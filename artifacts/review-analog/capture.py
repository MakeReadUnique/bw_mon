#!/usr/bin/env python3
"""Reopen a saved view and capture its actual nWave window, without simulation.

Example: ./capture.py start_stop_ns --display :91
Use --xvfb-bin /path/to/Xvfb to own and clean up a temporary display.
The PNG is written by wvCapture, never processed after capture.
"""
import argparse
import ctypes
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resize(display, xid, width, height, log):
    env = dict(os.environ, DISPLAY=display)
    tree = subprocess.check_output(['xwininfo', '-root', '-tree'], env=env,
                                   universal_newlines=True)
    candidates = [line for line in tree.splitlines()
                  if 'nwave' in line.lower() and '"' in line
                  and '<Verdi:nWave>' not in line and 'No File Opened' not in line]
    if len(candidates) != 1:
        raise RuntimeError('Expected one loaded nWave window: ' + tree)
    xid = int(re.search(r'0x[0-9a-f]+', candidates[0]).group(), 16)
    subprocess.check_call(['xprop', '-id', hex(xid), '-remove', 'WM_NORMAL_HINTS'],
                          env=env, stdout=log, stderr=log)
    x = ctypes.CDLL('libX11.so.6')
    x.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x.XOpenDisplay.restype = ctypes.c_void_p
    x.XMoveResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                                   ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
    x.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x.XCloseDisplay.argtypes = [ctypes.c_void_p]
    connection = x.XOpenDisplay(display.encode())
    if not connection:
        raise RuntimeError('Cannot open display ' + display)
    try:
        x.XMoveResizeWindow(connection, xid, 10, 10, width, height)
        x.XSync(connection, 0)
    finally:
        x.XCloseDisplay(connection)
    return tree


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


def main():
    metadata = json.loads((HERE / 'views.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('view', choices=list(metadata['views']))
    parser.add_argument('--display', default=os.environ.get('DISPLAY', ':91'))
    parser.add_argument('--xvfb-bin')
    parser.add_argument('--log-dir', type=Path)
    args = parser.parse_args()
    view = metadata['views'][args.view]
    fsdb = (HERE / view['fsdb']).resolve()
    assert digest(fsdb) == view['fsdb_sha256'], 'Frozen FSDB identity mismatch'
    work = Path(tempfile.mkdtemp(prefix='bw-analog-', dir=str(args.log_dir)
                                 if args.log_dir else None))
    shutil.copyfile(str(HERE / 'novas.rc'), str(work / 'novas.rc'))
    png = HERE / (args.view + '.png')
    ready = work / 'ready'
    release = work / 'capture-now'
    reopened = work / 'reopened.sav'
    probes = work / 'values.tsv'
    env = dict(os.environ, DISPLAY=args.display, BW_ANALOG_VIEW=args.view)
    code = 'source {' + str(HERE / 'open-view.tcl') + '}\n'
    code += 'wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 12\n'
    code += 'set fd [open {' + str(probes) + '} w]\n'
    for at, alias, expected in view['checks']:
        row = next(row for row in view['rows'] if row['alias'] == alias)
        code += 'wvSetCursor -win $w %s\n' % at
        query = 'wvGetCurValueString -win $w {%s}' % row['view_path']
        code += 'puts $fd "%s\\t%s\\t[%s]"\n' % (at, alias, query)
    code += 'close $fd\nwvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 2\n'
    code += 'wvSetCursor -win $w %s\n' % view['cursor_ns']
    code += 'set fd [open {' + str(ready) + '} w]\nputs $fd [wvGetXWindowId -id $w]\nclose $fd\n'
    code += ('set deadline [expr {[clock seconds] + 30}]\n'
             'while {![file exists {' + str(release) + '}]} {\n'
             '  if {[clock seconds] > $deadline} {error "capture handshake timeout"}\n'
             '  after 100\n  update\n}\nafter 800\nupdate\n')
    code += 'wvSaveSignal -win $w {' + str(reopened) + '}\n'
    code += 'wvCapture -win $w -file {' + str(png) + '}\nwvExit\n'
    code = ('if {[catch {\n' + code + '\n} err]} {puts stderr $err; '
            'puts stderr $errorInfo; wvExit}\n')
    (work / 'capture.tcl').write_text(code)
    command = ['verdi', '-nWave', '-play', str(work / 'capture.tcl')]
    process = display_process = None
    if png.exists():
        png.unlink()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    try:
        if args.xvfb_bin:
            with (work / 'xvfb.log').open('w') as display_log:
                display_process = subprocess.Popen(
                    [args.xvfb_bin, args.display, '-screen', '0', '1800x1100x24',
                     '-nolisten', 'tcp'], stdout=display_log, stderr=subprocess.STDOUT)
            time.sleep(.5)
            if display_process.poll() is not None:
                raise RuntimeError('Temporary display did not start; see ' + str(work))
        with (work / 'capture.log').open('w') as log:
            process = subprocess.Popen(command, cwd=str(work), env=env,
                                       stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 45
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.1)
            if not ready.exists():
                raise RuntimeError('Verdi did not load the saved view; see ' + str(work))
            xid = int(ready.read_text().strip(), 16)
            (work / 'xwindows.txt').write_text(resize(args.display, xid, *view['pixels'], log))
            release.touch()
            process.wait(timeout=45)
        assert process.returncode == 0 and png.is_file(), 'Fresh capture failed'
        raw = png.read_bytes()
        assert raw[:8] == b'\x89PNG\r\n\x1a\n'
        assert list(struct.unpack('>II', raw[16:24])) == view['pixels']
        restored = reopened.read_text()
        signal_rows = [line for line in restored.splitlines() if line.startswith('addSignal ')]
        assert len(signal_rows) == len(view['rows']), 'A requested public signal was not restored'
        assert all(any(line.endswith('/' + row['alias']) or line.endswith(' ' + row['alias'])
                       for line in signal_rows) for row in view['rows']), 'A signal alias was lost'
        analog_rows = [line for line in restored.splitlines() if line.startswith('addSignal -w analog')]
        assert len(analog_rows) == sum(bool(row['analog_range']) for row in view['rows'])
        assert all('-ds pwc' in row for row in analog_rows), 'Analog interpolation changed'
        assert 'windowTimeUnit 1ns' in restored
        assert digest(fsdb) == view['fsdb_sha256'], 'FSDB changed during viewing'
        values = []
        for line, check in zip(probes.read_text().splitlines(), view['checks']):
            at, alias, actual = line.split('\t')
            expected = check[2]
            held_text = actual.split('->')[-1].strip()
            phase_values = {label: int(value) for value, label in metadata['phase_values'].items()}
            held_value = phase_values[held_text] if held_text in phase_values else float(held_text)
            matched = abs(held_value - expected) <= max(1e-6, abs(expected) * 1e-6)
            values.append(dict(time_ns=float(at), alias=alias, expected=expected,
                               actual=actual, held_value=held_value, matches=matched))
        assert len(values) == len(view['checks']) and all(v['matches'] for v in values), values
        receipt = dict(source_asset_commit=metadata['source_asset_commit'], scene=view['scene'],
                       fsdb=view['fsdb'], fsdb_sha256=digest(fsdb), view=args.view,
                       sav_sha256=digest(HERE / (args.view + '.sav')), png_sha256=digest(png),
                       pixels=view['pixels'], started_utc=started, command=command, cwd=str(work),
                       display=args.display, capture_primitive='wvCapture', fresh=True,
                       saved_view_reopened=True, restored_analog_pwc_rows=len(analog_rows),
                       restored_time_unit='1ns', independent_checkpoints=values,
                       agent_visual_review='PENDING', human_review='PENDING',
                       marker_semantics=view['marker_semantics'],
                       raster_postprocessing=False, simulation_rerun=False)
        (HERE / (args.view + '.receipt.json')).write_text(json.dumps(receipt, indent=2) + '\n')
        # Retain the actual saved renderer state as proof of the portable-view reopen.
        # Normalize only directory references and trailing whitespace in view text.
        # FSDB and PNG bytes are untouched; the raw view is retained in the log directory.
        restored = restored.replace(str(fsdb), view['fsdb'])
        (HERE / (args.view + '.reopened.sav')).write_text(restored.rstrip() + '\n')
        print('Captured', args.view, 'from frozen FSDB; log:', work)
    finally:
        stop(process)
        stop(display_process)


if __name__ == '__main__':
    main()
