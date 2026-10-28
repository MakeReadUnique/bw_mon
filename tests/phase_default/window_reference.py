"""Independent physical-time reference for tb_phase_fixed's original inputs.

Only frozen configuration and the nine-column protocol input files enter this
model. No product window, phase label, history or quality result is an input.
All times are integer femtoseconds (the harness's timeprecision).
"""
from collections import namedtuple
from pathlib import Path

TICKS = 1000000
HERE = Path(__file__).resolve().parent
WindowReference = namedtuple('WindowReference',
                            'u ticks left full complete eligible bytes events y')
CaseReference = namedtuple('CaseReference', 'origin activity windows episodes')
EpisodeReference = namedtuple('EpisodeReference',
                              'first_ticks end_ticks end_u close_ticks first_u last_ticks')


def _episodes(activity, origin, horizon, silence):
    # All fixed input clocks have 1ns between edges, including reset edges.
    # size_known affects byte quality, while valid still determines activity.
    episodes = []
    first = last = None

    def finish(close, reset=False):
        end = close if reset else last + TICKS
        episodes.append(EpisodeReference(first, end, (end-origin)//TICKS,
                                         close, (first-origin)//TICKS, last))

    for tick, row in activity:
        if first is not None and tick >= last + (silence+1)*TICKS:
            finish(last + (silence+1)*TICKS)
            first = last = None
        if row['reset']:
            if first is not None:
                finish(tick, reset=True)
                first = last = None
        elif row['events']:
            if first is None:
                first = tick
            last = tick
    if first is not None:
        close = last + (silence+1)*TICKS
        # The fixed inputs all include sufficient trailing silence. Refuse an
        # unsupported unfinished input instead of silently inventing an edge.
        if close > horizon:
            raise ValueError('fixed input lacks an observed episode closure')
        finish(close)
    return tuple(episodes)


def reference_family(family, measurement_start=1, input_dir=HERE):
    """Return case references keyed by ID, using original raw input files.

    ``measurement_start`` is the common measurement start T; tb_phase_fixed
    first drives an edge at T+1fs. Its between-case reset lasts exactly 1ns.
    """
    raw_cases = {}
    for line in (Path(input_dir) / (family['id'] + '.txt')).read_text().splitlines():
        cid, u, b0, b1, b2, b3, events, known, reset = map(int, line.split())
        raw_cases.setdefault(cid, []).append(dict(u=u, members=[b0,b1,b2,b3],
                                                  events=events, known=known, reset=reset))
    result = {}
    origin = measurement_start
    for case_index, (cid, rows) in enumerate(raw_cases.items()):
        activity = tuple((origin + (r['u']-1)*TICKS + 1, r) for r in rows)
        episodes = _episodes(activity, origin, activity[-1][0], family['q'])
        windows = []
        # A reset suspends publication and release establishes a new epoch.
        # At an intermediate case boundary recording is disabled before reset;
        # the final case instead waits 2fs, exposing a due NS result at its end.
        end = origin + len(rows)*TICKS
        stop = end + int(case_index == len(raw_cases)-1 and family['basis'] == 'ns')
        epochs = []
        anchor = origin + (1 if family['basis'] == 'cycle' else 0)
        for tick, row in activity:
            if row['reset'] and anchor is not None:
                epochs.append((anchor, tick))
                anchor = None
            elif not row['reset'] and anchor is None:
                anchor = tick
        if anchor is not None:
            epochs.append((anchor, stop))
        schedule = [(anchor, right) for anchor, stop in epochs
                    for right in range(anchor + family['s']*TICKS, stop, family['s']*TICKS)]
        for anchor, right in schedule:
            u = (right-origin)//TICKS
            left = max(anchor, right-family['w']*TICKS)
            selected = [r for tick, r in activity if left <= tick < right and not r['reset']]
            amount = sum(sum(r['members']) for r in selected if r['events'] and r['known'])
            events = sum(r['events'] for r in selected)
            full = right-left == family['w']*TICKS
            complete = all(r['known'] for r in selected)
            active = next((e for e in episodes
                           if e.first_ticks < right < e.close_ticks), None)
            # Raw transfers from a prior episode cannot supply evidence for a
            # new episode. Own reset already removed them by restarting left.
            foreign = active is not None and any(
                e.close_ticks <= active.first_ticks and left <= e.last_ticks
                for e in episodes)
            eligible = full and complete and active is not None and not foreign
            windows.append(WindowReference(u, right, left, full, complete,
                                           eligible, amount, events,
                                           amount*TICKS/(right-left)))
        result[cid] = CaseReference(origin, activity, tuple(windows), episodes)
        origin += (len(rows)+1)*TICKS
    return result
