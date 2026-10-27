#!/usr/bin/env python3
"""Independently replay saved FSDB exports; no compilation, simulation, or GUI.

This checks the toy wave carrier only. The input table below is specified
independently of the SV implementation; prefix sums give the trailing 8 ns
window (or the observed duration during warmup). No product acceptance,
reset isolation, real phase/episode analysis, or capacity claim is made.
"""
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
OUT = HERE / 'evidence'
TOP = '/tb_cfg_group_probe'
P0 = [8] * 4 + [32] * 8 + [0] * 4 + [16] * 4 + [0] * 4
P1 = [16] * 8 + [0] * 8 + [8] * 4 + [0] * 4
UNIT_PS = {'s': 10 ** 12, 'ms': 10 ** 9, 'us': 10 ** 6,
           'ns': 1000, 'ps': 1, 'fs': 0.001}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def canonical(path):
    """Remove a vector suffix on the leaf, preserving generate-block indexes."""
    return re.sub(r'\[\d+:\d+\]$', '', path.strip())


def read_vcd(path):
    source = path.read_text()
    unit = re.search(r'\$timescale\s+(\d+)\s*(\w+)\s+\$end', source)
    require(unit is not None, 'VCD timescale missing: ' + str(path))
    scale = int(unit.group(1)) * UNIT_PS[unit.group(2)]
    scopes, declarations, by_code, snapshots = [], {}, {}, {}
    current, time, definitions = {}, 0, True
    for text in source.splitlines():
        text = text.strip()
        if definitions:
            words = text.split()
            if text.startswith('$scope '):
                scopes.append(words[2])
            elif text.startswith('$upscope'):
                scopes.pop()
            elif text.startswith('$var '):
                name = '/' + '/'.join(scopes + [words[4]])
                declarations[name] = {'type': words[1], 'width': int(words[2])}
                by_code[words[3]] = name
            elif text.startswith('$enddefinitions'):
                definitions = False
            continue
        if not text or text.startswith('$'):
            continue
        if text.startswith('#'):
            snapshots[time] = dict(current)
            time = int(text[1:]) * scale
            continue
        if text[0] in 'brs':
            value, code = text[1:].split(None, 1)
            if text[0] == 'r':
                value = float(value)
            elif text[0] == 'b':
                value = int(value, 2) if re.match(r'^[01]+$', value) else value
        elif text[0] in '01xz':
            value, code = text[0], text[1:]
            value = int(value) if value in '01' else value
        else:
            raise AssertionError('Unsupported VCD value: ' + text)
        current[by_code[code]] = value
    snapshots[time] = dict(current)
    return declarations, snapshots


def read_csv(path):
    require(path.stat().st_size > 0, 'Empty FSDB report: ' + str(path))
    with path.open(newline='') as handle:
        rows = list(csv.reader(handle))
    require(len(rows) > 1, 'No FSDB report data: ' + str(path))
    unit = re.fullmatch(r'Time\((\d+)(\w+)\)', rows[0][0])
    require(unit is not None, 'Unknown CSV time unit: ' + rows[0][0])
    scale = int(unit.group(1)) * UNIT_PS[unit.group(2)]
    names = [canonical(name) for name in rows[0][1:]]
    snapshots = {}
    for row in rows[1:]:
        if not row:
            continue
        require(len(row) == len(names) + 1, 'CSV row width mismatch')
        snapshots[float(row[0]) * scale] = dict(zip(names, row[1:]))
    return set(names), snapshots


def held(snapshots, at):
    eligible = [time for time in snapshots if time <= at]
    require(bool(eligible), 'No recorded value at time ' + str(at))
    return snapshots[max(eligible)]


def expected_samples(raw):
    prefix = [0]
    for value in raw:
        prefix.append(prefix[-1] + value)
    samples = []
    for count in range(1, 25):
        first = max(0, count - 4)
        byte_count = prefix[count] - prefix[first]
        samples.append({'time_ns': 2 * count, 'result_seq': count,
                        'window_bytes': byte_count,
                        'bandwidth_gbps': byte_count / (2.0 * (count - first)),
                        'active': 1, 'bytes_complete': 1,
                        'window_full': int(count >= 4),
                        'probe_state': 2 if count >= 4 else 1})
    return samples


def check_case(case, manifest_run):
    directory = OUT / case
    mapping = json.loads((directory / 'mapping.json').read_text())
    expected_mapping = {'g2': TOP + '/wave_slots[0]'}
    if case == 'second':
        expected_mapping['g1'] = TOP + '/wave_slots[1]'
    require(mapping == manifest_run['mapping'] == expected_mapping,
            case + ': Group ID mapping differs')
    require(sha(HERE / (case + '.cfg')) == manifest_run['cfg_sha256'],
            case + ': cfg fingerprint differs')
    require(sha(directory / 'waves.fsdb') == manifest_run['fsdb_sha256'],
            case + ': FSDB fingerprint differs')
    require('PROBE_PASS groups=%d samples=24' % len(mapping) in
            (directory / 'run.log').read_text(), case + ': completion marker missing')
    require('Failed to find' not in (directory / 'fsdbreport.log').read_text(),
            case + ': FSDB report contains missing signal warning')
    declarations, values = read_vcd(directory / 'waves.vcd')
    csv_names, csv_values = read_csv(directory / 'signals.csv')
    for index in range(24):
        at = (index + 1) * 2000
        sample = held(values, at)
        require(sample[TOP + '/p0_bytes'] == P0[index] and
                sample[TOP + '/p1_bytes'] == P1[index],
                case + ': stimulus differs at %d ps' % at)
    groups = {}
    for group_id, path in sorted(mapping.items()):
        require(declarations[path + '/bandwidth_gbps'] == {'type': 'real', 'width': 64},
                case + ': real bandwidth declaration missing')
        for leaf, width in [('result_seq', 64), ('window_bytes', 64),
                            ('active', 1), ('window_full', 1),
                            ('bytes_complete', 1), ('probe_state', 2)]:
            require(declarations[path + '/' + leaf]['width'] == width,
                    case + ': scalar declaration width differs: ' + leaf)
        require(path + '/group_id' in csv_names, case + ': FSDB string identity missing')
        raw = P0 if group_id == 'g1' else [a + b for a, b in zip(P0, P1)]
        expected = expected_samples(raw)
        enum_labels = set()
        for sample in expected:
            at = sample['time_ns'] * 1000
            require(at in values, case + ': publication timestamp missing')
            actual, report = held(values, at), held(csv_values, at)
            require(report[path + '/group_id'].strip('"') == group_id,
                    case + ': FSDB string identity differs at %d ps' % at)
            for leaf, wanted in sample.items():
                if leaf == 'time_ns':
                    continue
                found = actual[path + '/' + leaf]
                if leaf == 'bandwidth_gbps':
                    require(math.isclose(found, wanted, rel_tol=0, abs_tol=1e-12),
                            '%s %s %d ps bandwidth mismatch' % (case, group_id, at))
                    require(math.isclose(float(report[path + '/' + leaf]), wanted,
                                         rel_tol=0, abs_tol=1e-12),
                            case + ': FSDB CSV real differs from reference')
                else:
                    require(found == wanted, '%s %s %d ps %s mismatch: %s != %s' %
                            (case, group_id, at, leaf, found, wanted))
                    if leaf != 'probe_state':
                        bits = report[path + '/' + leaf]
                        require(re.fullmatch(r'[01]+', bits) is not None and
                                int(bits, 2) == wanted,
                                '%s %s %d ps CSV %s mismatch' % (case, group_id, at, leaf))
            state = report[path + '/probe_state'].strip('"')
            require(state == ('FULL' if sample['window_full'] else 'WARMUP'),
                    case + ': FSDB enum label differs: ' + state)
            enum_labels.add(state)
        require(held(csv_values, 0)[path + '/group_id'].strip('"') == group_id,
                case + ': initial string identity missing')
        groups[group_id] = {'path': path, 'real_declaration': declarations[path + '/bandwidth_gbps'],
                            'identity': group_id, 'identity_source': 'fsdbreport signals.csv',
                            'enum_labels_seen': sorted(enum_labels),
                            'matched_publications': len(expected), 'matched_values': expected}
    for index in range(len(mapping), 4):
        path = TOP + '/wave_slots[%d]' % index
        require(all(state[path + '/active'] == 0 for state in values.values()),
                case + ': unused wave slot became active')
    return {'groups': groups, 'stimulus_samples_checked': 24,
            'artifact_sha256': {name: sha(directory / name) for name in
                               ['waves.fsdb', 'waves.vcd', 'signals.csv', 'mapping.json', 'run.log']}}


def verify():
    manifest = json.loads((OUT / 'manifest.json').read_text())
    require(manifest['compile_count'] == 1, 'Experiment was not compiled once')
    require(sha(HERE / 'probe.sv') == manifest['source_sha256'], 'Source fingerprint differs')
    runs = {record['case']: record for record in manifest['runs']}
    require(set(runs) == {'first', 'second'}, 'Expected exactly two cfg runs')
    binary = manifest['build_payload_sha256']['simv']
    for record in runs.values():
        require(record['simv_sha256_before'] == record['simv_sha256_after'] == binary,
                'Runs do not use the same executable')
        require(record['unchanged_build_payloads'], 'Shared simulation payload changed')
    cases = {case: check_case(case, runs[case]) for case in ['first', 'second']}
    require(cases['first']['groups']['g2']['matched_values'] ==
            cases['second']['groups']['g2']['matched_values'],
            'g2 results changed after introducing g1')
    return {'status': 'PASS', 'scope': 'Toy cfg-created group wave-carrier evidence only',
            'method': 'Independent explicit p0/p1 input table and prefix-sum windows; '
                      'saved FSDB VCD and fsdbreport CSV values checked at every publication',
            'compile_count': 1, 'same_simv_sha256': binary,
            'source_sha256': sha(HERE / 'probe.sv'),
            'verifier_sha256': sha(Path(__file__)),
            'matched_group_publications': 72, 'g2_unchanged': True,
            'cases': cases,
            'limitations': ['No product group parser or statistics engine is exercised',
                            'The probe has four precompiled anonymous scalar wave slots',
                            'probe_state is a toy enum, not actual traffic phase analysis',
                            'No reset, traffic episode, performance expectation, or capacity acceptance',
                            'VCD type declarations and CSV values are exports from the recorded FSDB; '
                            'this verifier does not independently decode binary FSDB']}


def main():
    try:
        result = verify()
    except (AssertionError, KeyError, ValueError, OSError) as error:
        result = {'status': 'FAIL', 'error': str(error)}
    (OUT / 'verification.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(result['status'] + ': ' + (result.get('error') or
          '72 group publications, real values, string IDs, quality bits and enum labels checked'))
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
