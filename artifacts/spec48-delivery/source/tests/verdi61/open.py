#!/usr/bin/env python3
"""Open a frozen focused view, optionally with its actual compiled SV sources."""
import argparse
import json
import os
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[2]
SCENES = {'named_group': 'steady_ns', 'default_phase': 'constant',
          'sustained_boundary': 'alternating', 'steady_fail': 'alternating'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('view', choices=SCENES)
    parser.add_argument('--assets', type=Path,
                        default=ROOT / 'artifacts/verdi61-data')
    parser.add_argument('--source', action='store_true')
    args = parser.parse_args()
    scene = args.assets.resolve() / SCENES[args.view]
    command = ['verdi', '-ssf', str(scene / 'waves.fsdb')]
    if args.source:
        source = scene / 'source'
        source.mkdir(exist_ok=True)
        with tarfile.open(str(scene / 'source.tar.gz')) as archive:
            archive.extractall(str(source))
        rtl = sorted((source / 'rtl').glob('*.sv'),
                     key=lambda path: (path.name != 'bw_mon_pkg.sv', path.name))
        fixture = (source / 'tests/acceptance/scene.sv' if args.view == 'named_group'
                   else source / 'tests/tb_checker_default.sv')
        top = 'tb_acceptance_ns' if args.view == 'named_group' else 'tb_checker_default'
        command += ['-sv', '+incdir+' + str(source / 'rtl'), '-top', top]
        command += [str(path) for path in rtl + [fixture]]
    else:
        command += ['-nWave']
    tcl = scene / ('open-' + args.view + '.tcl')
    code = 'if {[llength [wvGetAllWindows]] == 0} {wvCreateWindow}\n'
    if args.source:
        code += 'srcResizeWindow 0 0 1920 1080\n'
    code += 'set w [lindex [wvGetAllWindows] 0]\n'
    code += 'wvRestoreSignal -win $w -appendSignals off {%s.sav}\n' % args.view
    code += ('wvSetPreference -win $w -hierName on -leftalign on '
             '-partial_hier off -hier_signal_name on\n')
    code += 'wvSetDefaultValue -win $w -analogFormat Engineer -analogPrecision 6\n'
    if args.source:
        scope = ('tb_acceptance_ns.scene.all_dmc' if args.view == 'named_group'
                 else 'tb_checker_default.group_mon')
        code += 'srcShowCalling {%s}\nsrcSelect -inst {%s}\n' % (scope, scope)
        code += 'srcSignalView -on\n'
    tcl.write_text(code)
    command += ['-play', str(tcl)]
    print(json.dumps(command), flush=True)
    os.chdir(str(scene))
    os.execvp(command[0], command)


if __name__ == '__main__':
    main()
