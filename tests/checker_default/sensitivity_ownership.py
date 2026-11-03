#!/usr/bin/env python3
"""Offline ownership-log sensitivity; synthetic negatives are not product runs.

Accept the four saved family outputs, then reject omitted results or duplicate
final rows. Copies preserve the consumed source logs and record their hashes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

FAMILIES = {'continuous': 1, 'platforms': 3, 'activity': 6, 'recovery': 11}
JOINT = ('BW_DEFAULT_CHECK ', 'BW_STAGE_STEP ', 'BW_STAGE_HANDOFF ')
VERIFIER = Path(__file__).resolve().with_name('check_ownership.py')


def fields(line):
    return dict(item.split('=', 1) for item in line.split() if '=' in item)


def mutate(lines, mode, first_case):
    current = None
    changed = []
    altered = False
    for line in lines:
        values = fields(line)
        if line.startswith('FIXED_CASE '):
            current = int(values['case'])
        joint = line.startswith(JOINT) and values.get('scope', '').startswith('phase.fixed.')
        group = values.get('scope_kind') == '1'
        remove = joint and (
            mode == 'missing_all' or
            (mode == 'missing_case' and current == first_case) or
            (mode == 'missing_kind' and group) or
            (mode == 'missing_case_kind' and current == first_case and group))
        single = (not altered and current == first_case and
                  line.startswith('BW_DEFAULT_CHECK ') and values.get('scope_kind') == '0')
        if remove or (mode == 'missing_result' and single):
            altered = True
            continue
        changed.append(line)
        if mode == 'duplicate_result' and single:
            changed.append(line)
            altered = True
    assert altered, ('mutation did not alter a required record', mode)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--producer-commit', required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'producer_commit': args.producer_commit, 'synthetic_negatives': True,
              'source_logs': {}, 'baselines': [], 'mutations': []}
    failures = []
    for family, first_case in FAMILIES.items():
        original = args.logs / ('phase_fixed_' + family + '.log')
        contents = original.read_bytes()
        report['source_logs'][family] = {'path': str(original.resolve()),
                                        'sha256': hashlib.sha256(contents).hexdigest()}
        lines = contents.decode().splitlines()
        for mode in ('baseline', 'missing_all', 'missing_case', 'missing_kind',
                     'missing_case_kind', 'missing_result', 'duplicate_result'):
            candidate = args.output / (family + '-' + mode + '.log')
            candidate.write_text('\n'.join(lines if mode == 'baseline' else
                                            mutate(lines, mode, first_case)) + '\n')
            result = subprocess.run([sys.executable, str(VERIFIER), str(candidate), family],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    universal_newlines=True)
            (args.output / (family + '-' + mode + '.verifier.log')).write_text(result.stdout)
            accepted = result.returncode == 0
            expected_acceptance = mode == 'baseline'
            phase_passed = 'PHASE_FIXED_PASS family=' + family in result.stdout
            correct_diagnostic = ('OWNERSHIP_PASS ' + family in result.stdout if expected_acceptance else
                                  ('OWNERSHIP_RESULT_KEYS' in result.stdout or
                                   'OWNERSHIP_RESULT_COUNT' in result.stdout))
            record = {'family': family, 'mode': mode, 'accepted': accepted,
                      'exit': result.returncode, 'phase_oracle_passed': phase_passed,
                      'expected_diagnostic': correct_diagnostic,
                      'passed': accepted == expected_acceptance and phase_passed and correct_diagnostic}
            report['baselines' if expected_acceptance else 'mutations'].append(record)
            if not record['passed']:
                failures.append((family, mode))
        assert original.read_bytes() == contents, ('source log modified', original)
    report['failures'] = failures
    (args.output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('OWNERSHIP_SENSITIVITY baselines=%d mutations=%d failures=%s' %
          (len(report['baselines']), len(report['mutations']), failures))
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
