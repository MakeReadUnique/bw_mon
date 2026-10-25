#!/usr/bin/env python3
"""Fixed public-module maximum-topology profiles; tracers are separately named."""
import argparse
from pathlib import Path

from scenario import Scenario, topology_summary
import run as harness


PROFILES = {
    'max-ns': dict(basis='ns', width=100, stride=10),
    'max-cycle': dict(basis='cycle', width=200, stride=20),
    'max-ns-short-unknown': dict(basis='ns', width=10, stride=10, variant='unknown'),
    'max-cycle-short-reset': dict(basis='cycle', width=20, stride=20, variant='reset'),
    'max-tracer-ns': dict(basis='ns', width=100, stride=10),
    'max-tracer-cycle': dict(basis='cycle', width=200, stride=20),
    'max-tracer-unknown': dict(basis='ns', width=10, stride=10, variant='unknown'),
    'max-tracer-reset': dict(basis='cycle', width=20, stride=20, variant='reset'),
}


def tracer_topology():
    # One depth-eight path plus sixteen direct consumers of subgroup0.
    # Its small size is for integration sensitivity, never nominal acceptance.
    groups = {0: [('point', p) for p in range(3)]}
    for g in range(1, 8):
        groups[g] = [('group', g - 1), ('point', g + 2)]
    for g in range(8, 23):
        groups[g] = [('group', 0), ('point', g + 2)]
    groups[23] = [('point', p) for p in range(25, 31)]
    return 32, groups


class MaximumScenario(Scenario):
    def __init__(self, name):
        tracer = 'tracer' in name
        super().__init__('common-ns', topology='common' if tracer else 'max',
                         roots=1, duration_ns=240 if tracer else 40000,
                         **PROFILES[name])
        self.name = name
        if tracer:
            self.points, self.groups = tracer_topology()
            self.topology, self.leaves = topology_summary(self.points, self.groups)
            self.config['topology'] = 'max-tracer'

    def manifest(self):
        result = super().manifest()
        result['acceptance_profile'] = 'tracer' not in self.name
        result['acceptance_ticket'] = 30
        result['topology_source'] = 'independent maximum_topology input; public modules instantiate every declared scope'
        result['scope_paths'] = dict(point='tb_bw_scale.points[N].slot.mon',
                                     group_owner='tb_bw_scale.groups[N].slot.mon',
                                     group_id='scale.gN')
        return result


def build_scenario(name):
    return MaximumScenario(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profiles', nargs='+', choices=list(PROFILES))
    parser.add_argument('--output-root', type=Path, default=harness.REPO / '.build/max-topology')
    parser.add_argument('--force-compile', action='store_true')
    args = parser.parse_args()
    for name in args.profiles:
        if not harness.run(build_scenario(name), args.output_root.resolve(), args.force_compile):
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
