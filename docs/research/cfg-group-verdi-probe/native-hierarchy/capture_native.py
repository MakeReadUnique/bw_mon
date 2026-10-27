#!/usr/bin/env python3
"""Inspect the renamed FSDB's native tree, with no waveform display aliases."""
import hashlib
import ctypes
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from capture import stop

OUT = HERE / 'evidence'
WORK = HERE.parents[3] / '.build/native-hierarchy/view'


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    display = ':95'
    fsdb = OUT / 'groups.fsdb'
    before = hashlib.sha256(fsdb.read_bytes()).hexdigest()
    ready, release = WORK / 'ready', WORK / 'release'
    for path in [ready, release]:
        if path.exists():
            path.unlink()
    paths = ['/tb_cfg_group_probe/g1/' + field for field in
             ['group_id', 'bandwidth_gbps', 'result_seq', 'window_bytes', 'window_full', 'probe_state']]
    paths += ['/tb_cfg_group_probe/g2/bandwidth_gbps']
    code = 'set w [lindex [wvGetAllWindows] 0]\n'
    code += 'set fd [open {' + str(OUT / 'native-tree.txt') + '} w]\n'
    code += 'puts $fd "SCOPES [wvGetScope -win $w /tb_cfg_group_probe]"\n'
    code += 'puts $fd "G1_SIGNALS [wvGetSignalsByScope -win $w /tb_cfg_group_probe/g1]"\nclose $fd\n'
    code += 'wvAddSignal -win $w -clear ' + ' '.join('{' + p + '}' for p in paths) + '\n'
    code += ('wvSetPreference -win $w -hierName on -hier_signal_name on -partial_hier off '
             '-leftalign on -piecewiseLinear off -pointStyle off\n')
    for path in paths:
        if path.endswith('bandwidth_gbps'):
            code += ('wvSelectSignal -win $w {' + path + '}\n'
                     'wvBusWaveform -win $w -analog\nwvChangeDisplayAttr -win $w -h 150 -lw 2\n')
    code += ('wvSelectSignal -win $w {}\nwvSetWindowTimeUnit -win $w 1 ns\n'
             'wvZoom -win $w 0 49\nwvZoomValue -win $w -fit\nwvSetCursor -win $w 18.001\n')
    code += 'wvGetSignalOpen -win $w\nupdate\n'
    code += 'wvSaveSignal -win $w {' + str(OUT / 'native.sav') + '}\n'
    code += 'set fd [open {' + str(ready) + '} w]\nputs $fd ready\nclose $fd\n'
    code += ('set deadline [expr {[clock seconds] + 40}]\n'
             'while {![file exists {' + str(release) + '}]} {\n'
             ' if {[clock seconds] > $deadline} {error "capture handshake timeout"}\n'
             ' after 100\n update\n}\n')
    code += 'wvSaveSignal -win $w {' + str(OUT / 'native.sav') + '}\nwvExit\n'
    tcl = WORK / 'capture.tcl'
    tcl.write_text('if {[catch {\n' + code + '\n} err]} {puts stderr $err; puts stderr $errorInfo; wvExit}\n')
    env = dict(os.environ, DISPLAY=display)
    viewer = server = None
    try:
        with (WORK / 'xvfb.log').open('w') as log:
            server = subprocess.Popen(['/tmp/bw-mon-spec13/xvfb/usr/bin/Xvfb', display,
                '-screen', '0', '1800x1100x24', '-nolisten', 'tcp'], stdout=log, stderr=subprocess.STDOUT)
        time.sleep(.5)
        assert server.poll() is None
        with (OUT / 'capture.log').open('w') as log:
            command = ['verdi', '-nWave', '-ssf', str(fsdb), '-play', str(tcl)]
            viewer = subprocess.Popen(command, cwd=str(WORK), env=env, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 40
            while not ready.exists() and viewer.poll() is None and time.monotonic() < deadline:
                time.sleep(.1)
            assert ready.exists(), 'Native tree probe failed; see capture.log'
            tree = subprocess.check_output(['xwininfo', '-root', '-tree'], env=env, universal_newlines=True)
            (OUT / 'xwindows.txt').write_text(tree)
            browser = next(line for line in tree.splitlines() if '"Get Signals"' in line)
            xid = re.search(r'0x[0-9a-f]+', browser).group()
            geometry = re.search(r'(\d+)x(\d+)\+(\d+)\+(\d+)', browser)
            left, top = int(geometry.group(3)), int(geometry.group(4))
            # Select g1 in the actual native tree using an X11 input event.
            x = ctypes.CDLL('libX11.so.6')
            xt = ctypes.CDLL('libXtst.so.6')
            x.XOpenDisplay.argtypes = [ctypes.c_char_p]
            x.XOpenDisplay.restype = ctypes.c_void_p
            x.XFlush.argtypes = [ctypes.c_void_p]
            x.XCloseDisplay.argtypes = [ctypes.c_void_p]
            xt.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
            xt.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
            connection = x.XOpenDisplay(display.encode())
            assert connection
            try:
                xt.XTestFakeMotionEvent(connection, -1, left + 85, top + 73, 0)
                for _ in range(2):
                    xt.XTestFakeButtonEvent(connection, 1, 1, 0)
                    xt.XTestFakeButtonEvent(connection, 1, 0, 0)
                    x.XFlush(connection)
                    time.sleep(.1)
            finally:
                x.XCloseDisplay(connection)
            time.sleep(.7)
            subprocess.run(['import', '-display', display, '-window', xid, str(OUT / 'native-tree.png')], check=True)
            release.touch()
            viewer.wait(timeout=15)
        assert viewer.returncode == 0
        saved = (OUT / 'native.sav').read_text()
        assert 'addRenameSig' not in saved, 'Display alias accidentally used'
        assert len([line for line in saved.splitlines() if line.startswith('addSignal ')]) == len(paths)
        native = (OUT / 'native-tree.txt').read_text()
        assert set(native.splitlines()[0].split()[1:]) == {'g1', 'g2'}
        assert 'bandwidth_gbps' in native and 'group_id' in native
        assert 'wave_slots' not in native
        assert hashlib.sha256(fsdb.read_bytes()).hexdigest() == before
        (OUT / 'native.sav').write_text(saved.replace(str(fsdb), 'groups.fsdb'))
        (OUT / 'capture.json').write_text(json.dumps({'command': command,
            'derived_fsdb_sha256': before, 'no_display_aliases': True,
            'native_tree_query': native, 'signals_added_by_native_path': paths,
            'image_capture': 'ImageMagick import of the native Get Signals window on isolated Xvfb',
            'raster_postprocessing': False, 'agent_visual_review': 'PENDING',
            'human_review': 'PENDING'}, indent=2) + '\n')
        print('Native FSDB scope and signal query PASS')
    finally:
        stop(viewer)
        stop(server)


if __name__ == '__main__':
    main()
