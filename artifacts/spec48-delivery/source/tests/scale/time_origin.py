"""Use the public startup origin to place independent relative input tables."""
import re


def measurement_start(log):
    rows = re.findall(r'^BW_READY .*?\btime_ticks=(\d+)\b', log, re.M)
    if len(rows) != 1 or int(rows[0]) <= 0:
        raise ValueError('expected exactly one positive public measurement start')
    return int(rows[0])


def absolute_episode(relative, start):
    result = dict(relative)
    for field in ('first_ticks', 'last_ticks', 'confirm_ticks'):
        if field in result:
            result[field] += start
    if result.get('tail_known'):
        result['tail_ticks'] += start
    return result
