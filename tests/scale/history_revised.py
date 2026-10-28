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
    def __init__(self, events, *, end, basis, width, stride, start=0):
        self.events = events
        self.ticks = [e[0] for e in events]
        self.start, self.end, self.basis, self.width, self.stride = start, end, basis, width, stride
        self.increments, self.prefix = [], []
        for scope in range(3):
            increments, prefix = [], [(0, 0, 0, 0)]
            for event in events:
                members = (0, 1) if scope == 2 else (scope,)
                values = [self.transfer(event[1 + 3*p:4 + 3*p]) for p in members]
                inc = tuple(sum(x[i] for x in values) for i in range(4))
                increments.append(inc)
                prefix.append(tuple(a+b for a, b in zip(prefix[-1], inc)))
            self.increments.append(increments)
            self.prefix.append(prefix)

    @staticmethod
    def transfer(value):
        valid, known, byte_count = value
        if valid == 2:  # X valid: neither occurrence nor bytes are known.
            return 0, 0, 1, 1
        if not valid:
            return 0, 0, 0, 0
        return (byte_count if known else 0), 1, int(not known), 0

    def raw(self, scope, edge):
        byte_inc, event_inc, ub, ue = self.increments[scope][edge-1]
        return dict(seq=edge, epoch=0, tick=self.ticks[edge-1], edge_index=edge,
                    byte_inc=byte_inc, event_inc=event_inc, bytes_complete=int(ub == 0),
                    events_complete=int(ue == 0), reset_points=0,
                    total_bytes=self.prefix[scope][edge][0], total_events=self.prefix[scope][edge][1], source_epoch=0)

    def window(self, scope, sequence):
        if self.basis == 'ns':
            right = self.start + sequence * self.stride * TICKS
            left = max(self.start, right-self.width*TICKS)
            lc = rc = 0
            full = right-self.start >= self.width*TICKS
        else:
            rc = 1 + sequence*self.stride
            lc = max(1, rc-self.width)
            left, right = self.ticks[lc-1], self.ticks[rc-1]
            full = rc-lc == self.width
        a, b = bisect_left(self.ticks, left), bisect_left(self.ticks, right)
        byte_count, event_count, ub, ue = [y-x for x, y in zip(self.prefix[scope][a], self.prefix[scope][b])]
        return dict(seq=sequence, epoch=0, left=left, right=right, left_cycle=lc, right_cycle=rc,
                    coverage_ticks=right-left, coverage_cycles=rc-lc,
                    bytes=byte_count, events=event_count, warmup=int(not full), full=int(full),
                    bytes_complete=int(ub == 0), events_complete=int(ue == 0), denominator_valid=1,
                    window_valid=int(full and ub == 0), reset=0,
                    gbps=Fraction(byte_count*TICKS, right-left),
                    bpc=Fraction(byte_count, rc-lc) if rc != lc else Fraction(0))

    @property
    def publication_count(self):
        return (self.end-self.start)//(self.stride*TICKS) if self.basis == 'ns' else (len(self.events)-1)//self.stride

    def windows(self, scope):
        return (self.window(scope, seq) for seq in range(1, self.publication_count+1))

    def at_measurement_start(self, start):
        return EventOracle([(e[0]+start,)+tuple(e[1:]) for e in self.events],
                           start=start, end=self.end+start, basis=self.basis,
                           width=self.width, stride=self.stride)


PROFILES = tuple('history-revised-' + basis + '-' + kind
                 for kind in ('seeded', 'expiry', 'deep') for basis in ('ns', 'cycle')) + ('history-revised-pending',)


class HistoryScenario:
    source_module = 'history_revised'
    variant = 'baseline'
    budget_seconds = 300

    def __init__(self, name):
        if name not in PROFILES:
            raise ValueError(name)
        self.name = name
        _, _, self.basis, self.kind = name.split('-')
        self.seed = 310026
        rng = random.Random(self.seed)
        events = []
        if self.kind == 'deep':
            self.width, self.stride = (40000 if self.basis == 'ns' else 80000), 1
            events = [(250000 + i*500000, 1, 1, 4294967294+i%2, 1, 1, 64) for i in range(80000)]
            end = 40000*TICKS
            self.resources = dict(event_segments=[80000, 1, 80000],
                                  clock_segments=[0 if self.basis == 'ns' else 1]*3,
                                  event_segments_final=[80000, 1, 80000])
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
        self.oracle = EventOracle(events, end=end, basis=self.basis, width=self.width, stride=self.stride)

    def manifest(self):
        return dict(schema='revised-history-v1', scenario=self.name, acceptance_ticket=31,
                    properties={'deep': ['H2', 'H3', 'H4', 'H7'], 'expiry': ['H1', 'H3', 'H4', 'H5', 'H7'],
                                'seeded': ['H1', 'H4', 'H5', 'H7']}[self.kind], kind=self.kind,
                    points=2, groups=1, topology={'history.group': ['history.p0', 'history.p1']},
                    basis=self.basis, width=self.width, stride=self.stride,
                    end_ticks=self.oracle.end, first_edge_ticks=250000,
                    actual_edges=len(self.oracle.events), windows_per_scope=self.oracle.publication_count,
                    seed=self.seed, input_time_basis='offset from published measurement start',
                    phase=dict(N=6,K=2,minimum_span=min(self.width,5*self.stride),
                    fit='adjacent pairs at actual physical times',steady_enter_rel=.04,steady_exit_rel=.08,
                    raw_rms_enter_rel=.10,raw_rms_exit_rel=.12,trend_rel=.10,paired_rms_rel=.025,absolute=0),
                    silence_threshold=30 if self.basis == 'ns' else 60,
                    hints='valid-only; unsupported handshake/credit hints remain disabled', waveform=False,
                    reference='expanded original input events; exact integer prefix sums and half-open bisection',
                    real_tolerance=dict(absolute=1e-9, relative=1e-12), resource_contract=self.resources,
                    input_file='event-input.txt', input_encoding='tick valid0 known0 bytes0 valid1 known1 bytes1')

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
