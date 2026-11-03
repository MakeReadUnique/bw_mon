#!/usr/bin/env python3
"""Capture native, unrenamed public signals in real Verdi/nWave."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GROUP = '/tb_checker_default/group_mon'
POINT = '/tb_checker_default/members[0]/point'
VIEWS = {
    'default_phase': ('constant', 4, 19, 7.000002),
    'sustained_boundary': ('alternating', 5, 9, 7.000002),
    'steady_fail': ('alternating', 5, 26, 20.000002),
}
FIELDS = ['scope_id', 'bandwidth_gbps', 'result_seq', 'window_start_ticks',
          'window_end_ticks', 'window_bytes', 'window_full', 'bytes_complete',
          'phase_current', 'phase_reason', 'phase_evidence_count',
          'phase_evidence_required', 'phase_candidate_count',
          'phase_candidate_required', 'phase_start_ticks',
          'phase_confirmation_ticks']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('view', choices=VIEWS)
    parser.add_argument('--output', type=Path, default=ROOT / '.build/verdi61')
    parser.add_argument('--display', default=':87')
    args = parser.parse_args()
    mode, begin, end, cursor = VIEWS[args.view]
    scene = args.output.resolve() / mode
    fsdb = scene / 'waves.fsdb'
    original = hashlib.sha256(fsdb.read_bytes()).hexdigest()
    paths = [GROUP + '/' + field for field in FIELDS]
    paths += [POINT + '/bandwidth_gbps', POINT + '/phase_current']
    sav = scene / (args.view + '.sav')
    lines = ['Magic 271485', 'Revision Verdi_W-2024.09-SP1',
             'viewPort 10 10 1860 1000 640 150',
             'openDirFile -d / "" "waves.fsdb"', 'signalSpacing 5',
             'windowTimeUnit 1ns', 'zoom %s %s 1n' % (begin, end),
             'cursor %s' % cursor, 'marker 0', 'top 0',
             'userMarker 6.000001 "BOUNDARY" ID_YELLOW5 long_dashed',
             'userMarker 7.000001 "CONFIRM" ID_ORANGE5 long_dashed',
             'addGroup "Native group: checker.group | W=S=1ns"']
    for path in paths:
        leaf = path.rsplit('/', 1)[1]
        if leaf == 'bandwidth_gbps':
            # Native saved-view syntax stores axis limits as IEEE double bytes.
            maximum = 500.0 if path.startswith(GROUP + '/') else 125.0
            axis = '.'.join(str(byte) for byte in struct.pack('>d', maximum))
            style = ('-w analog -ds pwc -c ID_CYAN5 -lw 2 -h 140 -gy -ry '
                     '-va ' + axis + ' 0.0.0.0.0.0.0.0')
        elif leaf in ['scope_id', 'phase_current', 'phase_reason']:
            style = '-h 24'
        else:
            style = '-h 24 -UNSIGNED -UDEC'
        lines.append('addSignal ' + style + ' ' + path)
    lines.append('addGroup "END"')
    sav.write_text('\n'.join(lines) + '\n')
    png = scene / (args.view + '.png')
    values = scene / (args.view + '-values.tsv')
    reopened = scene / (args.view + '.reopened.sav')
    for path in [png, values, reopened]:
        if path.exists():
            path.unlink()
    tcl = scene / ('capture-' + args.view + '.tcl')
    code = 'set w [lindex [wvGetAllWindows] 0]\n'
    code += 'wvRestoreSignal -win $w -appendSignals off {%s}\n' % sav
    code += ('wvSetPreference -win $w -hierName on -leftalign on '
             '-partial_hier off -hier_signal_name on\n')
    code += 'wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 6\n'
    code += 'wvResizeWindow -win $w 10 10 1860 1000\nafter 800\nupdate\n'
    code += 'set fd [open {%s} w]\n' % values
    for path in paths:
        code += 'puts $fd [format "%%s\\t%%s" {%s} [wvGetCurValueString -win $w {%s}]]\n' % (path, path)
    code += 'close $fd\nwvSaveSignal -win $w {%s}\n' % reopened
    code += 'wvCapture -win $w -file {%s}\nwvExit\n' % png
    tcl.write_text('if {[catch {\n' + code + '\n} err]} {\n'
                   'puts stderr $errorInfo\nwvExit\n}\n')
    command = ['verdi', '-nWave', '-ssf', str(fsdb), '-play', str(tcl)]
    with (scene / ('capture-' + args.view + '.log')).open('w') as log:
        subprocess.run(command, cwd=str(scene),
                       env=dict(os.environ, DISPLAY=args.display), stdout=log,
                       stderr=subprocess.STDOUT, timeout=60, check=True)
    raw = png.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack('>II', raw[16:24]) == (1860, 1000)
    restored = reopened.read_text()
    assert len([line for line in restored.splitlines()
                if line.startswith('addSignal ')]) == len(paths)
    assert 'addRenameSig' not in restored
    assert original == hashlib.sha256(fsdb.read_bytes()).hexdigest()
    actual = dict(line.split('\t', 1) for line in values.read_text().splitlines())
    # Worked snapshots of the unchanged fixture, independent of the FSDB.
    group_bw, point_bw, seq, left, right = {
        'default_phase': ('400.000000', '100.000000', '7', '6000001', '7000001'),
        'sustained_boundary': ('368.000000', '92.000000', '7', '6000001', '7000001'),
        'steady_fail': ('432.000000', '108.000000', '20', '19000001', '20000001'),
    }[args.view]
    expected = dict(zip(FIELDS, [
        'checker.group', group_bw, seq, left, right, group_bw.split('.')[0],
        '1', '1', 'BW_PHASE_STEADY', 'BW_PHASE_CONFIRMED', '6', '6', '0', '2',
        '6000001', '7000001']))
    expected = {GROUP + '/' + key: value for key, value in expected.items()}
    expected.update({POINT + '/bandwidth_gbps': point_bw,
                     POINT + '/phase_current': 'BW_PHASE_STEADY'})
    assert actual == expected, (actual, expected)
    manifest = {
        'view': args.view, 'mode': mode, 'command': command,
        'public_paths': paths, 'range_ns': [begin, end], 'cursor_ns': cursor,
        'fsdb_sha256': original, 'png_sha256': hashlib.sha256(raw).hexdigest(),
        'expected_values': expected, 'actual_values': actual,
        'automatic': 'PASS',
        'agent_visual_review': 'PENDING', 'human_review': 'PENDING',
    }
    (scene / (args.view + '-capture.json')).write_text(
        json.dumps(manifest, indent=2) + '\n')
    print('Captured native Verdi view:', png)


if __name__ == '__main__':
    main()
