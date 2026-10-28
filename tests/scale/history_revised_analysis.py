"""Original-event episode boundaries and rational least-squares phase reference.

The reference uses exact rational values and a simple list of original windows.
It neither imports nor follows the production compressed-history representation.
"""
from fractions import Fraction as F
import math


def episode_reference(oracle, scope, silence):
    increments = oracle.increments[scope]
    active = [i for i, inc in enumerate(increments) if inc[1]]
    if not active:
        return []
    def deadline(last):
        tail_index = last+1
        if tail_index >= len(oracle.ticks):
            return None, None
        tail = oracle.ticks[tail_index]
        if oracle.basis == 'ns':
            return tail, tail+silence*1000000
        due = tail_index+silence
        return tail, oracle.ticks[due] if due < len(oracle.ticks) else None
    groups = []
    first = last = active[0]
    for current in active[1:]:
        tail, due = deadline(last)
        uncertain_gap = any(inc[3] for inc in increments[last+1:current])
        if due is not None and due <= oracle.ticks[current] and not uncertain_gap:
            groups.append((first, last, tail, due, 2))
            first = current
        last = current
    tail, due = deadline(last)
    complete = due is not None and due <= oracle.end
    groups.append((first, last, tail, due if complete else oracle.end, 2 if complete else 4))
    result = []
    for index, (first, last, tail, due, status) in enumerate(groups, 1):
        selected = increments[first:last+1]
        bc, ec = all(x[2] == 0 for x in selected), all(x[3] == 0 for x in selected)
        duration = tail-oracle.ticks[first] if tail is not None else 0
        byte_count = sum(x[0] for x in selected)
        valid = status == 2 and tail is not None and bc and duration > 0
        result.append(dict(scope_kind=int(scope == 2), epoch=0, episode=index, result_seq=index,
                           status=status, first_ticks=oracle.ticks[first], last_ticks=oracle.ticks[last],
                           tail_ticks=tail or 0, confirm_ticks=due, bytes=byte_count,
                           events=sum(x[1] for x in selected), duration_ticks=duration,
                           first_known=1, last_known=1, tail_known=int(tail is not None),
                           bytes_complete=int(bc), events_complete=int(ec), member_reset=0,
                           e2e_valid=int(valid), e2e_gbps=F(byte_count*1000000, duration) if valid else F(0)))
    return result


def phase_reference(oracle, scope, episodes):
    result = []
    phase_identity = 0
    prior_last = -1
    first_full = (oracle.width+oracle.stride-1)//oracle.stride
    windows = list(oracle.windows(scope)) if oracle.publication_count-first_full+1 >= 6 else []
    # Maximum windows expose at most one full observation; N=6 cannot fit.
    for episode in episodes:
        evidence = []
        current = candidate = count = 0
        start = confirmation = candidate_at = 0
        active_identity = 0
        cap = episode['tail_ticks'] or episode['confirm_ticks']
        def close(at, known, reason):
            if current and min(at, cap) > start:
                result.append(dict(scope_kind=int(scope == 2), epoch=0, episode=episode['episode'],
                                   phase=active_identity, result_seq=len(result)+1, kind=current,
                                   start_ticks=start, end_ticks=min(at, cap), confirm_ticks=confirmation,
                                   start_known=1, end_known=int(known), reason=2 if at>cap else reason))
        for window in windows:
            if not episode['first_ticks'] < window['right'] <= episode['confirm_ticks']:
                continue
            foreign = window['left'] <= prior_last
            eligible = window['full'] and window['bytes_complete'] and window['denominator_valid'] and not foreign
            if not eligible:
                close(window['right'], True, 1)
                current = candidate = count = 0
                evidence = []
                continue
            evidence = (evidence+[window])[-6:]
            if len(evidence) != 6:
                continue
            position = 'right' if oracle.basis == 'ns' else 'right_cycle'
            minimum = min(oracle.width, 5*oracle.stride)*(1000000 if oracle.basis == 'ns' else 1)
            if evidence[-1][position]-evidence[0][position] < minimum:
                continue
            xs = [F(w['right'], 1000000) for w in evidence]
            ys = [w['gbps'] for w in evidence]
            paired = [((xs[i]+xs[i+1])/2, (ys[i]+ys[i+1])/2) for i in (0, 2, 4)]
            xm, ym = sum(xs)/6, sum(ys)/6
            slope = sum((x-xm)*(y-ym) for x, y in paired)/sum((x-xm)**2 for x, y in paired)
            delta = slope*(xs[-1]-xs[0])
            raw_variance = sum((y-ym-slope*(x-xm))**2 for x, y in zip(xs, ys))/6
            pair_variance = sum((y-ym-slope*(x-xm))**2 for x, y in paired)/3
            target = 0
            if current == 2 and abs(delta) <= ym*F(8, 100) and raw_variance <= (ym*F(12, 100))**2:
                target = 2
            elif abs(delta) <= ym*F(4, 100) and raw_variance <= (ym*F(10, 100))**2:
                target = 2
            elif ym > 0 and abs(delta) >= ym*F(10, 100) and pair_variance <= (ym*F(25, 1000))**2:
                target = 1 if delta > 0 else 3
            if target == current:
                candidate = count = 0
                continue
            if not count or candidate != target:
                candidate, count, candidate_at = target, 1, window['right']
            else:
                count += 1
            if count == 2:
                close(candidate_at, True, 0)
                current, start, confirmation = target, candidate_at, window['right']
                if current:
                    phase_identity += 1
                    active_identity = phase_identity
                candidate = count = 0
        close(cap, episode['status'] == 2, 2)
        prior_last = episode['last_ticks']
    return result


def episode_cv(oracle, scope, episode, prior_last=-1):
    if episode['status'] != 2 or not episode['tail_known']:
        return None
    selected = []
    for w in oracle.windows(scope):
        if not episode['first_ticks'] < w['right'] < episode['tail_ticks'] or not w['full'] or w['left'] <= prior_last:
            continue
        if not w['bytes_complete'] or not w['denominator_valid']:
            return None
        selected.append(w['gbps'])
    if len(selected) < 2:
        return None
    mean = sum(selected)/len(selected)
    if mean == 0:
        return None
    variance = sum((v-mean)**2 for v in selected)/len(selected)
    return 100*math.sqrt(float(variance))/float(mean)


def audit_packets(scenario, lines):
    """Require exact input-derived episode/phase/report identities and boundaries."""
    import re
    from collections import Counter
    errors = []
    def packets(prefix):
        return [dict(re.findall(r'(\w+)=([^\s]+)', line)) for line in lines if line.startswith(prefix+' ')]
    def fail(error, **detail):
        errors.append(dict(error=error, **detail))
    def compare(actual, expected, context):
        for field, value in expected.items():
            if isinstance(value, (F, float)):
                try:
                    good = abs(float(actual.get(field))-float(value)) <= 1e-9+1e-12*abs(float(value))
                except (TypeError, ValueError):
                    good = False
            else:
                good = actual.get(field) == str(value)
            if not good:
                fail('independent_'+context, field=field, expected=str(value), actual=actual.get(field), scope=actual.get('scope'))
    def indexed(prefix, keys):
        result = {}
        for packet in packets(prefix):
            key = tuple(packet.get(k) for k in keys)
            if key in result:
                fail('duplicate_'+prefix, identity=key)
            result[key] = packet
        return result
    ep_actual = indexed('BW_EPISODE', ('scope', 'epoch', 'episode', 'result_seq'))
    ph_actual = indexed('BW_PHASE', ('scope', 'epoch', 'episode', 'phase', 'result_seq'))
    metrics_actual = indexed('BW_PHASE_METRICS', ('scope', 'epoch', 'episode', 'phase', 'result_seq'))
    variation_actual = indexed('BW_VARIATION', ('scope', 'epoch', 'episode', 'phase', 'result_seq', 'interval'))
    steady_actual = indexed('BW_LAST_STEADY', ('scope', 'epoch', 'episode', 'result_seq'))
    check_actual = indexed('BW_CHECK', ('scope', 'scope_kind', 'epoch', 'episode', 'result_seq', 'kind', 'phase', 'metric'))
    ep_keys, ph_keys, variation_keys, check_keys = set(), set(), set(), set()
    conclusions = Counter()
    for scope, sid in enumerate(('history.p0', 'history.p1', 'history.group')):
        episodes = episode_reference(scenario.oracle, scope, 30 if scenario.basis == 'ns' else 60)
        phases = phase_reference(scenario.oracle, scope, episodes)
        for phase in phases:
            key = (sid, '0', str(phase['episode']), str(phase['phase']), str(phase['result_seq']))
            ph_keys.add(key)
            if key not in ph_actual:
                fail('missing_independent_phase', identity=key)
            else:
                compare(ph_actual[key], phase, 'phase')
            if key not in metrics_actual:
                fail('missing_phase_metrics', identity=key)
            variation_keys.add(key+('PHASE',))
        prior_last = -1
        for episode in episodes:
            key = (sid, '0', str(episode['episode']), str(episode['result_seq']))
            ep_keys.add(key)
            if key not in ep_actual:
                fail('missing_independent_episode', identity=key)
            else:
                compare(ep_actual[key], episode, 'episode')
            variation_keys.add((sid, '0', str(episode['episode']), '0', str(episode['result_seq']), 'EPISODE'))
            episode_phases = [p for p in phases if p['episode'] == episode['episode'] and p['kind'] == 2]
            if key not in steady_actual:
                fail('missing_last_steady', identity=key)
            else:
                steady = dict(found=int(bool(episode_phases)), selection_valid=int(bool(episode_phases) and episode['status'] == 2))
                if episode_phases:
                    selected = episode_phases[-1]
                    steady.update(phase=selected['phase'], phase_result_seq=selected['result_seq'],
                                  start_ticks=selected['start_ticks'], end_ticks=selected['end_ticks'])
                compare(steady_actual[key], steady, 'last_steady')
            cv = episode_cv(scenario.oracle, scope, episode, prior_last)
            for metric, value in [('e2e_bw', episode['e2e_gbps'] if episode['e2e_valid'] else None), ('episode_cv', cv)]:
                identity = (sid, str(int(scope == 2)), '0', str(episode['episode']), str(episode['result_seq']), 'episode', '0', metric)
                check_keys.add(identity)
                conclusion = 'WARNING' if value is None else 'PASS'
                conclusions[conclusion] += 1
                if identity not in check_actual:
                    fail('missing_configured_metric_identity', identity=identity)
                else:
                    expected = dict(conclusion=conclusion, actual='UNAVAILABLE' if value is None else value,
                                    start_ticks=episode['first_ticks'], end_ticks=episode['tail_ticks'])
                    compare(check_actual[identity], expected, 'configured_metric')
            prior_last = episode['last_ticks']
    for label, observed, expected in [('episode', ep_actual, ep_keys), ('phase', ph_actual, ph_keys),
                                      ('phase_metrics', metrics_actual, ph_keys), ('variation', variation_actual, variation_keys),
                                      ('last_steady', steady_actual, ep_keys), ('configured_metric', check_actual, check_keys)]:
        if set(observed) != expected:
            fail('complete_'+label+'_identities', missing=sorted(expected-set(observed)), extra=sorted(set(observed)-expected))
    summaries = packets('BW_SUMMARY')
    if len(summaries) != 1:
        fail('independent_summary_count')
    else:
        expected = dict(status='WARNING' if conclusions['WARNING'] else 'PASS',
                        scopes_done=3, scopes_expected=3, **{'pass': conclusions['PASS'], 'warning': conclusions['WARNING'], 'fail': 0})
        compare(summaries[0], expected, 'report_summary')
        summary_index = next(i for i, x in enumerate(lines) if x.startswith('BW_SUMMARY '))
        if any(i > summary_index and x.startswith(('BW_EPISODE ', 'BW_PHASE ', 'BW_PHASE_METRICS ', 'BW_VARIATION ', 'BW_LAST_STEADY ', 'BW_CHECK '))
               for i, x in enumerate(lines)):
            fail('summary_precedes_final_packet')
    return errors
