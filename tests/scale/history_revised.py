#!/usr/bin/env python3
"""Revised H1–H7 history evidence, using an expanded original-event oracle.

No production history, merging, clipping or floating-point accumulator is used
by the reference. Prefix sums are over individual input events; bisect applies
the spec's half-open physical interval to the original timestamps.
"""
import argparse
from bisect import bisect_left
from fractions import Fraction
from pathlib import Path
import random

TICKS = 1000000


class EventOracle:
    def __init__(self, events, *, end, basis, width, stride, start=0, resets=None):
        self.events = events
        self.ticks = [e[0] for e in events]
        self.start, self.end, self.basis, self.width, self.stride = start, end, basis, width, stride
        self.resets = {scope: sorted(intervals) for scope, intervals in (resets or {}).items()}
        self.increments, self.prefix = [], []
        self.totals, self.reset_prefix = [], []
        self.record_resets, self.accounted, self.record_epochs, self.source_epochs = [], [], [], []
        for scope in range(3):
            members = (0, 1) if scope == 2 else (scope,)
            increments, prefix = [], [(0, 0, 0, 0)]
            record_resets, accounted, epochs, sources = [], [], [], []
            for index, event in enumerate(events):
                # A member held in its own reset still publishes a zero
                # quality-bearing record; the scope's own held reset leaves
                # received records unaccounted instead.
                member_reset = 0
                inc = (0, 0, 0, 0)
                for p in members:
                    if self._holds(p, event[0]):
                        member_reset += 1
                        continue
                    inc = tuple(a+b for a, b in zip(inc, self.transfer(event[1 + 3*p:4 + 3*p])))
                increments.append(inc)
                prefix.append(tuple(a+b for a, b in zip(prefix[-1], inc)))
                record_resets.append(member_reset)
                accounted.append(not self._holds(scope, event[0]))
                epochs.append(self._epoch(scope, event[0]))
                # A point's recorder counts its own reset asserts; composed
                # group records carry no source epoch.
                sources.append(0 if scope == 2 else self._epoch(scope, event[0]))
            self.increments.append(increments)
            self.prefix.append(prefix)
            self.record_resets.append(record_resets)
            self.accounted.append(accounted)
            self.record_epochs.append(epochs)
            self.source_epochs.append(sources)
            self._totals_build(scope, increments, accounted)
            reset_running = [0]
            for count in record_resets:
                reset_running.append(reset_running[-1]+count)
            self.reset_prefix.append(reset_running)
        self._publications = [self._segment_publications(scope) for scope in range(3)]

    def _totals_build(self, scope, increments, accounted):
        """Per-record running totals of accounted increments since each clear."""
        totals = [(0, 0)]
        running = [0, 0]
        clears = [first for first, _ in self._intervals(scope)]
        next_clear = 0
        for i, inc in enumerate(increments):
            while next_clear < len(clears) and clears[next_clear] <= self.ticks[i]:
                running = [0, 0]
                next_clear += 1
            if accounted[i]:
                running[0] += inc[0]
                running[1] += inc[1]
            totals.append(tuple(running))
        self.totals.append(totals)

    def _intervals(self, scope):
        return self.resets.get(scope, ())

    def _holds(self, scope, tick):
        return any(first <= tick < second for first, second in self._intervals(scope))

    def _epoch(self, scope, tick):
        return sum(first <= tick for first, _ in self._intervals(scope))

    @staticmethod
    def transfer(value):
        valid, known, byte_count = value
        if valid == 2:  # X valid: neither occurrence nor bytes are known.
            return 0, 0, 1, 1
        if not valid:
            return 0, 0, 0, 0
        return (byte_count if known else 0), 1, int(not known), 0

    def _segments(self, scope):
        """Own resets split statistics into (origin, publish_limit, epoch) parts."""
        segments, origin, epoch = [], self.start, 0
        for first, second in self._intervals(scope):
            segments.append((origin, first, epoch))
            origin, epoch = second, epoch+1
        segments.append((origin, None, epoch))
        return segments

    def _segment_publications(self, scope):
        entries, sequence = [], 0
        if self.basis == 'ns':
            for origin, limit, epoch in self._segments(scope):
                step = self.stride*TICKS
                grid = origin+step
                while grid < (limit if limit is not None else self.end+1):
                    sequence += 1
                    entries.append((sequence, epoch, grid, origin))
                    grid += step
        else:
            edges = [i+1 for i in range(len(self.events)) if self.accounted[scope][i]]
            for origin, limit, epoch in self._segments(scope):
                if not edges:
                    break
                first = next((e for e in edges if self.ticks[e-1] >= origin), None)
                if first is None:
                    continue
                grid = first+self.stride
                while grid <= len(self.events) and self.ticks[grid-1] < (limit if limit is not None else self.end+1):
                    sequence += 1
                    entries.append((sequence, epoch, grid, first))
                    grid += self.stride
        return entries

    def raw(self, scope, edge):
        byte_inc, event_inc, ub, ue = self.increments[scope][edge-1]
        total_bytes, total_events = self.totals[scope][edge]
        return dict(seq=edge, epoch=self.record_epochs[scope][edge-1], tick=self.ticks[edge-1], edge_index=edge,
                    byte_inc=byte_inc, event_inc=event_inc, bytes_complete=int(ub == 0),
                    events_complete=int(ue == 0), reset_points=self.record_resets[scope][edge-1],
                    total_bytes=total_bytes, total_events=total_events,
                    source_epoch=self.source_epochs[scope][edge-1])

    def window(self, scope, sequence):
        seq, epoch, position, segment_origin = self._publications[scope][sequence-1]
        if self.basis == 'ns':
            right = position
            left = max(segment_origin, right-self.width*TICKS)
            lc = rc = 0
            full = right-segment_origin >= self.width*TICKS
        else:
            rc = position
            lc = max(segment_origin, rc-self.width)
            left, right = self.ticks[lc-1], self.ticks[rc-1]
            full = rc-segment_origin >= self.width
        a, b = bisect_left(self.ticks, left), bisect_left(self.ticks, right)
        byte_count, event_count, ub, ue = [y-x for x, y in zip(self.prefix[scope][a], self.prefix[scope][b])]
        resets = self.reset_prefix[scope][b]-self.reset_prefix[scope][a]
        if scope == 2:
            # Member-reset control intervals mark an aggregate window by time
            # overlap alone: a held member reset is real quality coverage even
            # when no sampling edge falls inside the pulse.
            resets += sum(1 for member in (0, 1) for first, second in self._intervals(member)
                          if first < right and second > left)
        return dict(seq=seq, epoch=epoch, left=left, right=right, left_cycle=lc, right_cycle=rc,
                    coverage_ticks=right-left, coverage_cycles=rc-lc,
                    bytes=byte_count, events=event_count, warmup=int(not full), full=int(full),
                    bytes_complete=int(ub == 0), events_complete=int(ue == 0), denominator_valid=1,
                    window_valid=int(full and ub == 0), reset=int(resets != 0),
                    gbps=Fraction(byte_count*TICKS, right-left),
                    bpc=Fraction(byte_count, rc-lc) if rc != lc else Fraction(0))

    @property
    def publication_counts(self):
        return tuple(len(entries) for entries in self._publications)

    @property
    def publication_count(self):
        counts = self.publication_counts
        assert len(set(counts)) == 1, 'uniform publication count requested for reset scenario'
        return counts[0]

    def windows(self, scope):
        return (self.window(scope, entry[0]) for entry in self._publications[scope])

    def at_measurement_start(self, start):
        return EventOracle([(e[0]+start,)+tuple(e[1:]) for e in self.events],
                           start=start, end=self.end+start, basis=self.basis,
                           width=self.width, stride=self.stride,
                           resets={scope: [(first+start, second+start) for first, second in intervals]
                                   for scope, intervals in self.resets.items()})


PROFILES = tuple('history-revised-' + basis + '-' + kind
                 for kind in ('seeded', 'expiry', 'deep', 'reset') for basis in ('ns', 'cycle')) + \
    ('history-revised-pending', 'history-revised-ns-overrun')


class HistoryScenario:
    source_module = 'history_revised'
    variant = 'baseline'
    budget_seconds = 300

    def __init__(self, name):
        if name not in PROFILES:
            raise ValueError(name)
        self.name = name
        pieces = name.split('-')
        self.basis, self.kind = (pieces[2], pieces[3]) if len(pieces) == 4 else (pieces[2], 'overrun')
        self.seed = 310026
        rng = random.Random(self.seed)
        events = []
        self.resets = {}
        self.overrun_edges = 0
        if self.kind == 'deep' or self.kind == 'overrun':
            self.width, self.stride = (40000 if self.basis == 'ns' else 80000), 1
            if self.kind == 'deep' and self.basis == 'ns':
                # The final 2GHz edge lands exactly on the T+40us budget
                # endpoint (one half period stretched): the endpoint window is
                # published from a real same-tick sampling edge, which is the
                # supported way to complete endpoint work without a drain tick.
                ticks = [250000 + i*500000 for i in range(79999)] + [40000*TICKS]
            else:
                ticks = [250000 + i*500000 for i in range(80000)]
            events = [(t, 1, 1, 4294967294+i % 2, 1, 1, 64) for i, t in enumerate(ticks)]
            end = 40000*TICKS
            self.resources = dict(event_segments=[80000, 2 if self.kind == 'deep' and self.basis == 'ns' else 1, 80000],
                                  clock_segments=[0 if self.basis == 'ns' else 1]*3,
                                  event_segments_final=[80000, 2 if self.kind == 'deep' and self.basis == 'ns' else 1, 80000])
            if self.kind == 'overrun':
                # Three real 2GHz edges past the immutable T+40us budget; the
                # first must be rejected with a runtime warning and isolation.
                self.overrun_edges = 3
        elif self.kind == 'expiry':
            self.width, self.stride = (127 if self.basis == 'ns' else 257), 3
            tick = 250000
            for i in range(8192):
                active = int(i%2048 < 1024)
                events.append((tick, active, 1, 63+2*(i%2), active, 1, 64))
                tick += 500000 if i%2 == 0 else 1000000
            end = tick+TICKS
            self.resources = dict(event_segments_min=[160, 80, 160],
                                  clock_segments_min=[0 if self.basis == 'ns' else 128]*3,
                                  event_segments_final=[0, 0, 0], drain_cycles=4)
        elif self.kind == 'reset':
            # Real 2GHz traffic across the whole immutable T+40us budget with a
            # point-held reset (30-32us, byte step 64->80 on release) and an
            # independent group-held reset (10-12us). Resets restart statistics
            # and episodes; they never extend the measurement budget.
            self.width, self.stride = (7 if self.basis == 'ns' else 17), 3
            for i in range(80000):
                tick = 250000 + i*500000
                events.append((tick, 1, 1, 64 if tick < 32000500000 else 80, 1, 1, 64))
            end = 40000*TICKS
            self.resets = {0: [(30000500000, 32000500000)], 2: [(10000500000, 12000500000)]}
            self.resources = dict(event_segments_min=[1, 1, 1],
                                  clock_segments_min=[0 if self.basis == 'ns' else 1]*3,
                                  event_segments_final=[1, 1, 1])
        else:
            self.width, self.stride = (7 if self.basis == 'ns' else 17), 3
            tick = 250000
            for i in range(1024):
                active = int(i < 896)
                valid = 2 if i%101 == 37 else int(rng.randrange(5) != 0)
                value = rng.choice((0, 4, 8, 16, 63, 65))
                if i < 160:
                    valid, value = 1, 8 if i < 83 else 16
                events.append((tick, valid if active else 0, int(i%97 != 41), value, active, 1, 64))
                tick += (500000 if i < 256 or i >= 512 else 1000000) + (50000000 if i == 383 else 0)
            end = tick+40*TICKS
            self.resources = dict(event_segments_min=[4, 1, 4], event_segments_final=[0, 0, 0])
        self.oracle = EventOracle(events, end=end, basis=self.basis, width=self.width, stride=self.stride,
                                  resets=self.resets or None)

    def manifest(self):
        properties = {'deep': ['H2', 'H3', 'H4', 'H7'], 'expiry': ['H1', 'H3', 'H4', 'H5', 'H7'],
                      'seeded': ['H1', 'H4', 'H5', 'H7'],
                      'reset': ['H2', 'H3', 'H4', 'H5'],
                      'overrun': ['H2', 'H7']}[self.kind]
        value = dict(schema='revised-history-v2', scenario=self.name, acceptance_ticket=59,
                    properties=properties, kind=self.kind,
                    points=2, groups=1, topology={'history.group': ['history.p0', 'history.p1']},
                    basis=self.basis, width=self.width, stride=self.stride,
                    end_ticks=self.oracle.end, first_edge_ticks=250000,
                    actual_edges=len(self.oracle.events),
                    windows_per_scope=list(self.oracle.publication_counts),
                    seed=self.seed, input_time_basis='offset from published measurement start',
                    phase=dict(N=6,K=2,minimum_span=min(self.width,5*self.stride),
                    fit='adjacent pairs at actual physical times',steady_enter_rel=.04,steady_exit_rel=.08,
                    raw_rms_enter_rel=.10,raw_rms_exit_rel=.12,trend_rel=.10,paired_rms_rel=.025,absolute=0),
                    silence_threshold=30 if self.basis == 'ns' else 60,
                    hints='valid-only; unsupported handshake/credit hints remain disabled', waveform=False,
                    reference='expanded original input events; exact integer prefix sums and half-open bisection',
                    real_tolerance=dict(absolute=1e-9, relative=1e-12), resource_contract=self.resources,
                    input_file='event-input.txt', input_encoding='tick valid0 known0 bytes0 valid1 known1 bytes1')
        if self.resets:
            value['resets'] = {str(scope): list(intervals) for scope, intervals in self.resets.items()}
        if self.overrun_edges:
            value['overrun_edges'] = self.overrun_edges
            value['budget_ticks'] = 40000000000
            value['driven_end_ticks'] = events_driven_end(self)
            value['overrun_contract'] = ('edges past T+40us are rejected by a runtime SIM_TIME_LIMIT '
                                         'warning with scope isolation; startup errors remain fatal')
        return value

    def generate(self, out):
        from history_revised_generate import generate
        generate(self, out)

    def simulation_args(self, attempt):
        return ['+HISTORY_DIR='+str(attempt), '+ACTUAL='+str(attempt/'actual.csv'), '+BW_EXPECT='+str(attempt/'expect.cfg')]

    def verify(self, attempt):
        from history_revised_audit import verify
        return verify(self, attempt)


def build_scenario(name):
    if name == 'history-revised-pending':
        from history_revised_pending import PendingScenario
        return PendingScenario()
    return HistoryScenario(name)


def events_driven_end(scenario):
    """Last driven edge tick, including deliberate over-budget edges."""
    ticks = scenario.oracle.ticks
    return ticks[-1] + scenario.overrun_edges*500000


if __name__ == '__main__':
    import run as harness
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profiles', nargs='+', choices=PROFILES)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--force-compile', action='store_true')
    args = parser.parse_args()
    for profile in args.profiles:
        if not harness.run(build_scenario(profile), args.output_root.resolve(), args.force_compile):
            raise SystemExit(1)
