#!/usr/bin/env python3
"""Run the four fixed phase inputs cold, serially, with auditable stage timings.

Uses tests/run.py unchanged as the compile/simulation/verification entry. The
900-second budget includes advisory-lock waiting, preparation, verification and
cleanup. No checker, sweep or scale campaign is added to this fixed matrix.
"""
import argparse
from datetime import datetime
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
CASES = ['phase_fixed_'+f for f in ('continuous','platforms','activity','recovery')]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',required=True,type=Path)
    parser.add_argument('--lock',required=True,type=Path)
    args=parser.parse_args()
    start=time.monotonic();deadline=start+900
    args.evidence.mkdir(parents=True,exist_ok=True)
    report={'started_utc':datetime.utcnow().isoformat()+'Z','budget_seconds':900,
            'cases':CASES,'cold':True,'host':list(os.uname()),'python':sys.version,
            'commands':[],'completed':False,'checker_claim':False}
    original_run=subprocess.run
    report['source']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()
    report['dirty_source']=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip())
    build=ROOT/'.build/tests/tb_phase_fixed'
    locked=False;lock=None;result=1

    def timed_run(command,**kwargs):
        command=list(map(str,command));name=Path(command[0]).name
        stage='compile' if name=='vcs' else 'simulation' if name=='simv' else 'verify'
        entry={'stage':stage,'command':command,'cwd':str(kwargs.get('cwd',ROOT))}
        began=time.monotonic();remaining=deadline-began
        if remaining<=0:raise TimeoutError('fixed-phase budget exhausted before '+stage)
        timeout=min(kwargs.get('timeout',remaining),remaining)
        if stage=='simulation':
            popen_kwargs=dict(kwargs);popen_kwargs.pop('timeout',None)
            process=subprocess.Popen(command,bufsize=1,**popen_kwargs)
            expired=[False]
            def kill():
                expired[0]=True;process.kill()
            timer=threading.Timer(timeout,kill);timer.daemon=True;timer.start()
            lines=[];ready=None
            try:
                for line in process.stdout:
                    lines.append(line)
                    if ready is None and line.startswith('BW_READY '):ready=time.monotonic()
                code=process.wait()
            finally:
                timer.cancel()
            finished=time.monotonic()
            entry['initialization_observed_seconds']=None if ready is None else ready-began
            entry['execution_after_ready_observed_seconds']=None if ready is None else finished-ready
            entry['initialization_measurement']='host process start to observed existing BW_READY line; includes loader and pipe observation latency'
            entry['timed_out']=expired[0]
            completed=subprocess.CompletedProcess(command,code,''.join(lines))
            if expired[0]:entry['returncode']=code;entry['seconds']=finished-began;report['commands'].append(entry);raise TimeoutError('simulation deadline')
        else:
            kwargs['timeout']=timeout
            completed=original_run(command,**kwargs)
        entry['returncode']=completed.returncode;entry['seconds']=time.monotonic()-began
        report['commands'].append(entry)
        return completed

    try:
        args.lock.parent.mkdir(parents=True,exist_ok=True)
        lock=args.lock.open('a+')
        while True:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);locked=True;break
            except BlockingIOError:
                if time.monotonic()>=deadline:raise TimeoutError('fixed-phase budget exhausted while waiting for serial lock')
                time.sleep(.05)
        report['lock_wait_seconds']=time.monotonic()-start
        prepare=time.monotonic()
        if build.exists():shutil.rmtree(str(build))
        spec=importlib.util.spec_from_file_location('bw_component_entry',str(ROOT/'tests/run.py'))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        report['preparation_seconds']=time.monotonic()-prepare
        subprocess.run=timed_run
        previous_argv=sys.argv;sys.argv=[str(ROOT/'tests/run.py'),'--no-cache']+CASES
        try:result=module.main()
        finally:sys.argv=previous_argv;subprocess.run=original_run
        counts={stage:sum(c['stage']==stage for c in report['commands']) for stage in ('compile','simulation','verify')}
        report['stage_command_counts']=counts
        report['completed']=result==0 and counts=={'compile':1,'simulation':4,'verify':4}
    except Exception as error:
        report['error']=repr(error)
    finally:
        subprocess.run=original_run
        cleanup=time.monotonic()
        if locked and build.exists():
            for path in build.iterdir():
                if path.is_file() and (path.suffix in ('.log','.json') or path.name=='source.sha256'):
                    shutil.copy2(str(path),str(args.evidence/path.name))
            shutil.rmtree(str(build))
        report['cleanup_seconds']=time.monotonic()-cleanup
        report['total_seconds']=time.monotonic()-start
        report['within_budget']=report['total_seconds']<=900
        report['passed']=bool(report['completed'] and report['within_budget'])
        (args.evidence/'timing.json').write_text(json.dumps(report,indent=2)+'\n')
        if locked:fcntl.flock(lock,fcntl.LOCK_UN)
        if lock is not None:lock.close()
    print('PHASE_FIXED_CAMPAIGN {} seconds={:.3f} evidence={}'.format('PASS' if report['passed'] else 'INCOMPLETE',report['total_seconds'],args.evidence))
    return 0 if report['passed'] else 1

if __name__=='__main__':sys.exit(main())
