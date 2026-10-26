#!/usr/bin/env python3
"""Daily or complete revised acceptance, serial by default with enforced budgets."""
import argparse
import fcntl
import json
from pathlib import Path
import sys
import time
from bounded import REPO, execute_stage, save, sha, run_bounded
from topology_revised import build_scenario as topology_scenario, PROFILES as TOPOLOGY
from history_revised import build_scenario as history_scenario, PROFILES as HISTORY

COMPONENTS = ['numeric_arithmetic_known','numeric_add_unknown','numeric_mul_unknown','numeric_add_overflow',
              'numeric_mul_overflow','numeric_queue_range','numeric_subtract_known','numeric_subtract_underflow',
              'numeric_subtract_unknown','history_trace_ns','history_trace_cycle','phase_delayed',
              'metrics_stopped_history','reset_member_controls','reset_rewarm']


def profiles(tier):
    if tier=='full':
        return list(TOPOLOGY)+list(HISTORY)
    return [n for n in TOPOLOGY if '-quick-' in n]+[
        n for n in HISTORY if 'seeded' in n or 'pending' in n]


def run_suite(tier,output,cache_mode,lock_path):
    output.mkdir(parents=True,exist_ok=True)
    lock_path.parent.mkdir(parents=True,exist_ok=True)
    waiting=time.monotonic()
    with lock_path.open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        lock_wait=time.monotonic()-waiting
        started=time.monotonic()
        budget=1800 if tier=='full' else (300 if cache_mode=='cold' else 120)
        manifest=dict(schema='bw-revised-suite-v1',tier=tier,cache_mode=cache_mode,budget_seconds=budget,
                      state='RUNNING',checked_pass=False,qualification_lock=str(lock_path),
                      infrastructure_lock_wait_seconds=lock_wait,concurrency=1,profiles=[],stages={})
        path=output/('suite-'+tier+'-'+cache_mode+'.json')
        save(path,manifest)
        passed=True
        for name in profiles(tier):
            scenario=(topology_scenario if name in TOPOLOGY else history_scenario)(name)
            scenario.budget_seconds=min(scenario.budget_seconds,max(0,budget-(time.monotonic()-started)))
            if scenario.budget_seconds<=0:
                passed=False;break
            okay=run_bounded(scenario,output,cache_mode=='cold')
            latest=json.loads((output/(name+'-latest.json')).read_text())
            manifest['profiles'].append(dict(name=name,**latest))
            save(path,manifest)
            if not okay:
                passed=False;break
        if passed and tier=='full':
            directory=output/('components-'+cache_mode)
            # The legacy component runner's cache omits native tool identities.
            # Force these small builds in both modes rather than reuse it.
            result=execute_stage([sys.executable,str(REPO/'tests/run.py'),'--no-cache']+COMPONENTS,
                                 directory,'components',budget-(time.monotonic()-started))
            manifest['stages']['components']=result
            passed=result['state']=='COMPLETED'
            cases=json.loads((REPO/'tests/cases.json').read_text())
            selected=[c for c in cases if c['name'] in COMPONENTS]
            source_set={REPO/'tests/run.py',REPO/'tests/cases.json'}
            for c in selected:
                source_set.add(REPO/'tests'/(c['top']+'.sv'))
                source_set.update(REPO/'tests'/f for f in c.get('sources',[]))
            manifest['component_cases']=selected
            manifest['component_source_sha256']={str(p.relative_to(REPO)):sha(p) for p in sorted(source_set)}
            evidence=directory/'evidence';evidence.mkdir(parents=True,exist_ok=True)
            import shutil
            for c in selected:
                build=REPO/'.build/tests'/c['top']
                for file in (c['name']+'.log','compile.log','source.sha256'):
                    source=build/file
                    if source.exists():
                        target=evidence/c['top']/file;target.parent.mkdir(parents=True,exist_ok=True)
                        shutil.copyfile(str(source),str(target))
            save(path,manifest)
        if passed and tier=='full':
            directory=output/('common-replay-'+cache_mode)
            result=execute_stage([sys.executable,str(REPO/'tests/scale/history_evidence/final-campaign/verify.py')],
                                 directory,'common-replay',budget-(time.monotonic()-started))
            manifest['stages']['common_replay']=result
            passed=result['state']=='COMPLETED'
        if passed:
            directory=output/('recorded-replay-'+tier+'-'+cache_mode)
            result=execute_stage([sys.executable,str(REPO/'tests/scale/revised_evidence.py'),'audit-runs','--member-sensitivity']+
                                 [r['manifest'] for r in manifest['profiles']],directory,'recorded-replay',
                                 budget-(time.monotonic()-started))
            manifest['stages']['recorded_replay']=result
            passed=result['state']=='COMPLETED'
        elapsed=time.monotonic()-started
        manifest.update(state='VERIFIED' if passed and elapsed<=budget else 'INCOMPLETE',
                        checked_pass=passed and elapsed<=budget,elapsed_seconds=elapsed,
                        budget_met=elapsed<=budget,expected_profiles=profiles(tier))
        save(path,manifest)
        print(('PASS ' if manifest['checked_pass'] else 'FAIL ')+str(path),flush=True)
        return manifest['checked_pass']


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('tier',choices=('quick','full'))
    p.add_argument('--output-root',type=Path,required=True)
    p.add_argument('--cache-mode',choices=('cold','hot'),required=True)
    p.add_argument('--lock',type=Path,default=REPO/'.build/revised-qualification.lock')
    a=p.parse_args()
    return 0 if run_suite(a.tier,a.output_root.resolve(),a.cache_mode,a.lock.resolve()) else 1


if __name__=='__main__':
    raise SystemExit(main())
