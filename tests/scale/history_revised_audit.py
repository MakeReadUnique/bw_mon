"""Audit completed original-event differential runs; missing evidence never passes."""
import csv
import json
import re
import copy
from pathlib import Path
from time_origin import measurement_start


def kv(line):
    return dict(re.findall(r'(\w+)=([^\s]+)', line))


def verify(s, attempt):
    from history_revised_generate import SUMMARY
    differences = []
    def require(condition, error, **details):
        if not condition:
            differences.append(dict(error=error, **details))
    log = (attempt/'simulation.log').read_text() if (attempt/'simulation.log').exists() else ''
    try:
        origin = measurement_start(log)
    except ValueError as error:
        require(False, 'measurement_start', detail=str(error)); origin = 0
    s = copy.copy(s)
    s.oracle = s.oracle.at_measurement_start(origin)
    rows = []
    if (attempt/'actual.csv').exists():
        with (attempt/'actual.csv').open() as stream:
            rows = list(csv.DictReader(stream))
    observed = {}
    for row in rows:
        try:
            values = {k:int(v) for k, v in row.items()}
            require(set(values) == set(SUMMARY) and all(v >= 0 for v in values.values()), 'complete_resource_columns')
            scope = values['scope']
            require(scope not in observed and scope in (0, 1, 2), 'scope_identity', scope=scope)
            observed[scope] = values
        except (ValueError, TypeError, KeyError):
            require(False, 'malformed_actual', row=row)
    require(set(observed) == {0, 1, 2}, 'complete_scope_set')
    for scope, row in observed.items():
        if scope not in (0, 1, 2):
            continue
        raw = s.oracle.raw(scope, len(s.oracle.events))
        for field, expected in dict(records=len(s.oracle.events), windows=s.oracle.publication_count,
                                    total_bytes=raw['total_bytes'], total_events=raw['total_events'],
                                    transport_frames_final=0, transport_controls_final=0).items():
            require(row.get(field) == expected, 'final_exact', scope=scope, field=field,
                    actual=row.get(field), expected=expected)
        for prefix, observed_field in [('event_segments', 'event_segments_peak'), ('clock_segments', 'clock_segments_peak'),
                                       ('event_segments_final', 'event_segments_final')]:
            if prefix in s.resources:
                expected = s.resources[prefix][scope]
                require(row.get(observed_field) == expected, 'resource_exact', scope=scope, field=observed_field,
                        expected=expected, actual=row.get(observed_field))
            if prefix+'_min' in s.resources:
                expected = s.resources[prefix+'_min'][scope]
                require(row.get(observed_field, -1) >= expected, 'resource_depth', scope=scope, field=observed_field,
                        minimum=expected, actual=row.get(observed_field))
        if s.kind == 'expiry':
            # Resource sampler sees both raw acceptance and publication at the
            # drain edge. The exact counter is deduplicated in the fixture.
            require(row.get('drain_checkpoints') == 4, 'repeated_drain', scope=scope, actual=row.get('drain_checkpoints'))
    lines = log.splitlines()
    require(len([x for x in lines if x.startswith('HISTORY_PASS ')]) == 1, 'completion_marker')
    require(len([x for x in lines if x.startswith('HISTORY_RUN_START ')]) == 1, 'start_marker')
    require(len([x for x in lines if x.startswith('BW_READY ')]) == 1, 'ready_marker')
    require(not re.search(r'Fatal:|Error-\[|HISTORY_\w*MISMATCH|BW_CORE_ERROR|BW_CFG_WARNING', log), 'diagnostic')
    summaries = [kv(x) for x in lines if x.startswith('BW_SUMMARY ')]
    require(len(summaries) == 1 and summaries[0].get('scopes_done') == '3' and
            summaries[0].get('scopes_expected') == '3', 'final_report_barrier')
    episodes = [kv(x) for x in lines if x.startswith('BW_EPISODE ')]
    phases = [kv(x) for x in lines if x.startswith('BW_PHASE ')]
    scopes = {'history.p0': 0, 'history.p1': 1, 'history.group': 2}
    by_scope = {sid: [] for sid in scopes}
    for record in episodes:
        sid = record.get('scope')
        require(sid in by_scope, 'episode_identity', scope=sid)
        if sid not in by_scope:
            continue
        by_scope[sid].append(record)
        require(record.get('result_seq') == str(len(by_scope[sid])), 'episode_sequence', scope=sid)
    for sid, scope in scopes.items():
        require(bool(by_scope[sid]), 'missing_episode', scope=sid)
        if s.kind == 'deep':
            require(len(by_scope[sid]) == 1, 'deep_episode_count', scope=sid)
            if by_scope[sid]:
                actual = by_scope[sid][0]
                expected = dict(status=4, first_ticks=origin+250000, last_ticks=origin+39999750000,
                                bytes=s.oracle.raw(scope, 80000)['total_bytes'], events=80000*(2 if scope == 2 else 1),
                                tail_known=0, bytes_complete=1, events_complete=1, e2e_valid=0)
                for key, value in expected.items():
                    require(actual.get(key) == str(value), 'deep_episode_contract', scope=sid,
                            field=key, expected=value, actual=actual.get(key))
        elif s.kind == 'expiry':
            require(len(by_scope[sid]) == 4, 'expiry_episode_count', scope=sid)
            for i, actual in enumerate(by_scope[sid]):
                if i >= 4:
                    break
                first = i*2048
                tail = first+1024
                confirmation = s.oracle.ticks[tail]+30000000 if s.basis == 'ns' else s.oracle.ticks[tail+60]
                expected = dict(status=2, first_ticks=s.oracle.ticks[first], last_ticks=s.oracle.ticks[tail-1],
                                tail_ticks=s.oracle.ticks[tail], confirm_ticks=confirmation,
                                bytes=65536*(2 if scope == 2 else 1), events=1024*(2 if scope == 2 else 1),
                                bytes_complete=1, events_complete=1, tail_known=1, e2e_valid=1)
                for key, value in expected.items():
                    require(actual.get(key) == str(value), 'expiry_episode_contract', scope=sid,
                            episode=i+1, field=key, expected=value, actual=actual.get(key))
    last_sequence = {}
    for record in phases:
        sid = record.get('scope')
        seq = last_sequence.get(sid, 0)+1
        require(sid in scopes and record.get('result_seq') == str(seq), 'phase_identity_sequence', record=record)
        last_sequence[sid] = seq
    if s.kind == 'deep':
        require(not phases, 'maximum_window_has_insufficient_phase_evidence')
    checks = [kv(x) for x in lines if x.startswith('BW_CHECK ')]
    require(len(checks) == len(episodes)*2, 'configured_report_completeness', actual=len(checks), expected=len(episodes)*2)
    require(not any(x.get('conclusion') == 'FAIL' for x in checks), 'unexpected_performance_failure')
    # Unknown observations in seeded p0/group persist in their old episodes even
    # though the final known-zero window has recovered (checked in the stream).
    if s.kind == 'seeded':
        for sid in ('history.p0', 'history.group'):
            require(any(x.get('bytes_complete') == '0' and x.get('e2e_valid') == '0' for x in by_scope[sid]),
                    'old_episode_remains_incomplete', scope=sid)
    from history_revised_analysis import audit_packets
    differences.extend(audit_packets(s, lines))
    storage_differences, storage_counts = verify_storage(s.oracle, attempt/'storage-runs.txt', expected_snapshots(s))
    differences.extend(storage_differences)
    require(storage_counts['snapshots'] >= 3, 'all_scope_storage_snapshots')
    evidence = dict(measurement_start_ticks=origin,storage_verification=storage_counts, schema='revised-history-verification-v1', profile=s.name,
                    scopes=len(rows), checked_raw=sum(r.get('records', 0) for r in observed.values()),
                    checked_windows=sum(r.get('windows', 0) for r in observed.values()),
                    original_input_events=len(s.oracle.events), episode_records=len(episodes), phase_records=len(phases),
                    real_tolerance=dict(absolute=1e-9, relative=1e-12),
                    resource_measurements=observed, difference_count=len(differences))
    (attempt/'diffs.json').write_text(json.dumps(differences, indent=2, sort_keys=True)+'\n')
    (attempt/'verification.json').write_text(json.dumps(evidence, indent=2, sort_keys=True)+'\n')
    return not differences, evidence


def verify_storage(oracle, path, expected=None):
    """Expand observed runs; every expected tuple comes from original inputs.

    This is diagnostic instrumentation, not an integration API. Public-output
    checks remain independent and are required in addition to these observations.
    """
    differences = []
    counts = dict(snapshots=0, expanded_events=0, expanded_clock_boundaries=0, event_runs=0, clock_runs=0)
    current = None
    observed_snapshots = {scope: [] for scope in (0, 1, 2)}
    def fail(error, **details):
        differences.append(dict(error=error, **details))
    if not path.exists():
        return [dict(error='storage_export_missing')], counts
    with path.open() as stream:
        for number, line in enumerate(stream, 1):
            pieces = line.split()
            try:
                kind, values = pieces[0], list(map(int, pieces[1:]))
                scope, seq = values[:2]
                if kind == 'S':
                    if current is not None:
                        fail('snapshot_not_closed', line=number)
                    _, _, tick, edge, left, left_cycle = values
                    if scope not in (0, 1, 2) or not 0 <= edge <= len(oracle.events):
                        raise ValueError('snapshot identity')
                    publication = (tick-oracle.start)//(oracle.stride*1000000) if oracle.basis == 'ns' else max(0, edge-1)//oracle.stride
                    reference = oracle.window(scope, publication) if publication else {'left': oracle.start, 'left_cycle': 0}
                    if (left, left_cycle) != (reference['left'], reference['left_cycle']):
                        fail('snapshot_independent_left', scope=scope, snapshot=seq)
                    left, left_cycle = reference['left'], reference['left_cycle']
                    observed_snapshots[scope].append((seq, tick, edge))
                    expected_events = []
                    for i, event in enumerate(oracle.events[:edge]):
                        inc = oracle.increments[scope][i]
                        if (event[0] < left if oracle.basis == 'ns' else i+1 < left_cycle):
                            continue
                        if any(inc):
                            expected_events.append((event[0], i+1, inc[0], inc[1], int(inc[2] == 0), int(inc[3] == 0), 0))
                    clocks = [(oracle.ticks[i-1], i) for i in range(max(1, edge-oracle.width), edge+1)] if oracle.basis == 'cycle' else []
                    current = dict(key=(scope, seq), expected=expected_events, clocks=clocks, events=[], actual_clocks=[])
                    counts['snapshots'] += 1
                elif current is None or current['key'] != (scope, seq):
                    fail('snapshot_identity', line=number)
                elif kind == 'E':
                    _, _, first, first_edge, count, tick_step, edge_step, byte_count, events, bc, ec, reset, last, last_edge = values
                    if count < 1 or count > len(oracle.events):
                        raise ValueError('run count')
                    if last != first+(count-1)*tick_step or last_edge != first_edge+(count-1)*edge_step:
                        fail('run_last_position', scope=scope, snapshot=seq)
                    current['events'].extend((first+i*tick_step, first_edge+i*edge_step, byte_count, events, bc, ec, reset)
                                             for i in range(count))
                    counts['expanded_events'] += count
                    counts['event_runs'] += 1
                elif kind == 'C':
                    _, _, first, first_edge, count, step, last = values
                    if count < 1 or count > len(oracle.events):
                        raise ValueError('clock count')
                    if last != first+(count-1)*step:
                        fail('clock_last_position', scope=scope, snapshot=seq)
                    current['actual_clocks'].extend((first+i*step, first_edge+i) for i in range(count))
                    counts['expanded_clock_boundaries'] += count
                    counts['clock_runs'] += 1
                elif kind == 'Z':
                    if current['events'] != current['expected']:
                        fail('expanded_event_sequence', scope=scope, snapshot=seq,
                             expected_count=len(current['expected']), actual_count=len(current['events']))
                    if current['actual_clocks'] != current['clocks']:
                        fail('expanded_clock_sequence', scope=scope, snapshot=seq,
                             expected_count=len(current['clocks']), actual_count=len(current['actual_clocks']))
                    current = None
                else:
                    fail('storage_record_kind', line=number)
            except (ValueError, IndexError):
                fail('malformed_storage_record', line=number)
    if current is not None:
        fail('snapshot_not_closed')
    if expected is not None:
        for scope in (0, 1, 2):
            if observed_snapshots[scope] != expected[scope]:
                fail('required_snapshot_schedule', scope=scope, expected=expected[scope], actual=observed_snapshots[scope])
    if counts['snapshots'] == 0:
        fail('no_storage_snapshots')
    return differences, counts


def expected_snapshots(scenario):
    stride = 0 if scenario.kind == 'deep' else 512 if scenario.kind == 'expiry' else 64
    edges = len(scenario.oracle.events)
    checkpoints = list(range(stride, edges+1, stride)) if stride else []
    planned = [(i+1, scenario.oracle.ticks[edge-1], edge) for i, edge in enumerate(checkpoints)]
    planned.append((len(planned)+1, scenario.oracle.end, edges))
    return {scope: list(planned) for scope in (0, 1, 2)}
