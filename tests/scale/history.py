#!/usr/bin/env python3
"""Complementary nominal history/update profiles; tracers never replace targets."""
import argparse
from pathlib import Path
from scenario import Scenario
import run as harness

CELLS={
 'ns-short-dense':dict(basis='ns',width=10,stride=1),
 'cycle-short-dense':dict(basis='cycle',width=20,stride=2),
 'ns-long-dense':dict(basis='ns',width=40000,stride=1),
 'cycle-long-dense':dict(basis='cycle',width=80000,stride=1),
 'ns-control-clock':dict(basis='ns',width=7,stride=3,variant='group-clock',history_controls=True),
 'cycle-control-clock':dict(basis='cycle',width=7,stride=3,variant='group-clock',history_controls=True),
}
PROFILES={}
for scale in ('common','max'):
    for cell,settings in CELLS.items():PROFILES['history-'+scale+'-'+cell]=dict(settings,scale=scale,tracer=False)
for cell,settings in CELLS.items():PROFILES['history-tracer-'+cell]=dict(settings,scale='common',tracer=True)

class HistoryScenario(Scenario):
    def __init__(self,name):
        options=dict(PROFILES[name]);scale=options.pop('scale');tracer=options.pop('tracer')
        super().__init__('common-ns',topology=scale,roots=1 if tracer else 32,duration_ns=240 if tracer else 40000,
                         **options)
        self.name=name
        if self.variant=='group-clock':
            # Inputs remain three disjoint arithmetic progressions, not per-edge arrays.
            segments=[(250000,500000,20),(10250000,1000000,10),(30250000,500000,420)] if tracer else [(250000,500000,1000),(500250000,1000000,50),(600250000,500000,78800)]
            from scenario import Clock
            self.clock=Clock(segments)
            self.reset_start=70100000 if tracer else 300100000
            self.reset_end=71100000 if tracer else 301100000
            self.unknown_tick=40250000 if tracer else 100250000
            self.unknown_edge=self.clock.lt(self.unknown_tick)+1
            self.config.update(clock_segments=segments,reset_start_ticks=self.reset_start,reset_end_ticks=self.reset_end,unknown_tick=self.unknown_tick,group_reset_index=0)
    def manifest(self):
        value=super().manifest();value['acceptance_profile']=not PROFILES[self.name]['tracer'];value['acceptance_ticket']=31
        value['matrix_cell']=self.name;value['coverage']=('nominal40us clock/control variant; regular2GHz baselines separate' if self.variant=='group-clock' else 'nominal40us/2GHz baseline') if value['acceptance_profile'] else 'small public tracer only'
        return value

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profiles',nargs='+',choices=list(PROFILES))
    parser.add_argument('--output-root',type=Path,default=harness.REPO/'.build/history')
    parser.add_argument('--force-compile',action='store_true')
    parser.add_argument('--legacy-long',action='store_true',help='explicitly select the superseded 40us research matrix')
    args=parser.parse_args()
    if any(not PROFILES[name]['tracer'] for name in args.profiles) and not args.legacy_long:
        parser.error('40us profiles are legacy research; use revised_suite.py, or explicitly add --legacy-long')
    for name in args.profiles:
        if not harness.run(HistoryScenario(name),args.output_root.resolve(),args.force_compile):return 1
    return 0
if __name__=='__main__':raise SystemExit(main())
