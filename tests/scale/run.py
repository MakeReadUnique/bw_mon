#!/usr/bin/env python3
"""Reproducible public-module scale acceptance. No memory/speed cap or fake DUT."""
import argparse,csv,datetime,hashlib,json,os,re,shutil,signal,subprocess,sys,time
from collections import Counter
from fractions import Fraction as F
from pathlib import Path
from scenario import Scenario,PROFILES,CSV_FIELDS
from generate import generate
from time_origin import measurement_start, absolute_episode

REPO=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def utc():return datetime.datetime.utcnow().isoformat()+'Z'
def save(path,value):
    tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n');tmp.replace(path)
def capture(cmd):
    try:return subprocess.check_output(cmd,cwd=str(REPO),stderr=subprocess.STDOUT,universal_newlines=True).strip()
    except (OSError,subprocess.CalledProcessError) as e:return str(e)
def family_rss(pid):
    statuses={}
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            s=(p/'status').read_text();parent=int(re.search(r'^PPid:\s+(\d+)',s,re.M).group(1));m=re.search(r'^VmRSS:\s+(\d+)',s,re.M)
            statuses[int(p.name)]=(parent,int(m.group(1)) if m else 0)
        except (OSError,AttributeError):pass
    tree={pid}
    while True:
        more={p for p,(parent,rss) in statuses.items() if parent in tree}-tree
        if not more:break
        tree.update(more)
    return sum(statuses.get(p,(0,0))[1] for p in tree)

def execute(cmd,cwd,log_path,time_path,manifest_path,manifest,stage):
    wrapped=['/usr/bin/time','-v','-o',str(time_path)]+cmd
    result=dict(command=wrapped,cwd=str(cwd),started_utc=utc(),state='RUNNING',log=str(log_path),time_v=str(time_path))
    manifest[stage]=result;manifest['state']=stage.upper()+'_RUNNING';save(manifest_path,manifest)
    start=time.monotonic();peak=0
    with log_path.open('w') as out:
        process=subprocess.Popen(wrapped,cwd=str(cwd),stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        result['pid']=process.pid;save(manifest_path,manifest)
        try:
            while process.poll() is None:
                peak=max(peak,family_rss(process.pid));time.sleep(1)
        except KeyboardInterrupt:
            result['state']='OPERATOR_INTERRUPTED';os.killpg(process.pid,signal.SIGTERM)
        rc=process.wait()
    result.update(returncode=rc,finished_utc=utc(),elapsed_wall_seconds=time.monotonic()-start,observed_process_family_peak_rss_kib=peak)
    if result['state']=='RUNNING':result['state']='COMPLETED' if rc==0 else 'FAILED'
    if time_path.exists():
        m=re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)',time_path.read_text())
        if m:result['time_v_peak_rss_kib']=int(m.group(1))
    save(manifest_path,manifest);return result

def keyvalues(line):return dict(re.findall(r'(\w+)=([^\s]+)',line))

def verify(s,attempt):
    diffs=[]
    log=(attempt/'simulation.log').read_text() if (attempt/'simulation.log').exists() else ''
    try:origin=measurement_start(log)
    except ValueError as error:
        diffs.append(dict(error='measurement_start',detail=str(error)));origin=0
    expected=list(csv.DictReader((attempt/'expected.csv').open()))
    actual=list(csv.DictReader((attempt/'actual.csv').open())) if (attempt/'actual.csv').exists() else []
    ref={(r['kind'],r['index']):r for r in expected};obs={}
    for row in actual:
        k=(row.get('kind'),row.get('index'))
        if k in obs:diffs.append(dict(error='duplicate_scope',key=k))
        obs[k]=row
    for k in sorted(set(ref)|set(obs)):
        if k not in ref or k not in obs:diffs.append(dict(error='extra_scope' if k not in ref else 'missing_scope',key=k));continue
        for field in CSV_FIELDS:
            a,e=obs[k].get(field),ref[k][field]
            if field in ('window_left','window_right','raw_tick'):e=str(int(e)+origin)
            if field in ('window_gbps','window_bpc'):
                try:good=abs(F(a)-F(e))<=F(1,10**9)+F(1,10**12)*abs(F(e))
                except (ValueError,TypeError,ZeroDivisionError):good=False
            else:good=a==e
            if not good:diffs.append(dict(key=k,field=field,expected=e,actual=a))
    if 'SCALE_PASS ' not in log or re.search(r'Fatal:|Error-\[|SCALE_\w*MISMATCH|BW_CFG_WARNING',log):diffs.append(dict(error='simulation_completion_or_diagnostic'))
    starts=[keyvalues(l) for l in log.splitlines() if l.startswith('SCALE_RUN_START ')]
    ends=[keyvalues(l) for l in log.splitlines() if l.startswith('SCALE_PASS ')]
    if len(starts)!=1 or len(ends)!=1:diffs.append(dict(error='start_or_completion_count',starts=len(starts),ends=len(ends)))
    for marker in starts+ends:
        if marker.get('end_ticks')!=str(origin+s.end):diffs.append(dict(error='measurement_endpoint',expected=origin+s.end,actual=marker.get('end_ticks')))
    summaries=[keyvalues(l) for l in log.splitlines() if l.startswith('BW_SUMMARY ')]
    checks=[keyvalues(l) for l in log.splitlines() if l.startswith('BW_CHECK ')]
    episodes=[keyvalues(l) for l in log.splitlines() if l.startswith('BW_EPISODE ')]
    phases=[keyvalues(l) for l in log.splitlines() if l.startswith('BW_PHASE ')]
    last_steady=[keyvalues(l) for l in log.splitlines() if l.startswith('BW_LAST_STEADY ')]
    observed_episodes={};metrics=Counter(c.get('conclusion') for c in checks)
    byid={s.identity(k,i):(k,i) for k,i in s.scopes()}
    for e in episodes:
        sid=e.get('scope');seq=int(e.get('result_seq','0'))
        if sid not in byid:diffs.append(dict(error='unknown_episode_scope',record=e));continue
        kind,index=byid[sid]
        expected_seq=len(observed_episodes.get(sid,[]))+1
        if seq!=expected_seq:diffs.append(dict(error='episode_sequence',scope=sid,expected=expected_seq,actual=seq))
        observed_episodes.setdefault(sid,[]).append(e)
        references=s.expected_episodes(kind,index)
        if not 1<=seq<=len(references):
            diffs.append(dict(error='extra_episode',scope=sid,seq=seq));continue
        fields=absolute_episode(references[seq-1],origin)
        for f,value in fields.items():
            if f=='e2e_gbps':
                try:good=abs(F(e.get(f))-value)<=F(1,10**9)+F(1,10**12)*abs(value)
                except (ValueError,TypeError,ZeroDivisionError):good=False
            else:good=e.get(f)==str(value)
            if not good:diffs.append(dict(error='episode',scope=sid,seq=seq,field=f,expected=str(value),actual=e.get(f)))
    for sid,(kind,index) in byid.items():
        n=len(s.expected_episodes(kind,index))
        if len(observed_episodes.get(sid,[]))!=n:diffs.append(dict(error='episode_count',scope=sid,expected=n,actual=len(observed_episodes.get(sid,[]))))
    required_metrics={'e2e_bw','steady_bw','ramp_time','fall_time','steady_window_min','steady_window_max','steady_stddev','steady_cv','episode_window_min','episode_window_max','episode_stddev','episode_cv'}
    conclusions={}
    for c in checks:
        key=(c.get('scope'),c.get('epoch'),c.get('episode'))
        metric=c.get('metric');conclusions.setdefault(key,Counter())[metric]+=1
        if metric not in required_metrics:diffs.append(dict(error='unexpected_metric',record=c))
        if c.get('conclusion')=='WARNING' and c.get('actual')!='UNAVAILABLE':diffs.append(dict(error='warning_compared_as_number',record=c))
    for e in episodes:
        key=(e.get('scope'),e.get('epoch'),e.get('episode'));counts=conclusions.get(key,Counter())
        if set(counts)!=required_metrics:diffs.append(dict(error='missing_metric_rules',key=key,observed=dict(counts)))
        if any(counts[m]!=1 for m in required_metrics-{'ramp_time','fall_time'}):diffs.append(dict(error='repeated_final_metric',key=key,observed=dict(counts)))
    high={}
    for p in phases:
        sid=p.get('scope');seq=int(p.get('result_seq','0'))
        if sid not in byid or seq!=high.get(sid,0)+1:diffs.append(dict(error='phase_identity_sequence',record=p))
        high[sid]=seq
    for x in last_steady:
        if not s.config.get('allow_final_steady_selection') and x.get('selection_valid')!='0':diffs.append(dict(error='truncated_last_steady_selection',record=x))
    if len(last_steady)!=len(episodes):diffs.append(dict(error='last_steady_record_count'))
    if len(summaries)!=1:diffs.append(dict(error='summary_count',actual=len(summaries)))
    else:
        x=summaries[0];scopes=s.points+len(s.groups)
        if x.get('scopes_done')!=str(scopes) or x.get('scopes_expected')!=str(scopes):diffs.append(dict(error='summary_scope_barrier',actual=x))
        for field,conclusion in [('pass','PASS'),('fail','FAIL'),('warning','WARNING')]:
            if x.get(field)!=str(metrics[conclusion]):diffs.append(dict(error='summary_counter',field=field,actual=x.get(field),expected=metrics[conclusion]))
        want='FAIL' if metrics['FAIL'] else 'WARNING' if metrics['WARNING'] else 'PASS'
        if x.get('status')!=want:diffs.append(dict(error='summary_status',actual=x.get('status'),expected=want))
        if not metrics['WARNING']:diffs.append(dict(error='missing_expected_truncation_warning'))
        all_lines=log.splitlines();summary_pos=next((i for i,l in enumerate(all_lines) if l.startswith('BW_SUMMARY ')),-1)
        if any(i>summary_pos and l.startswith(('BW_EPISODE ','BW_PHASE ','BW_CHECK ')) for i,l in enumerate(all_lines)):diffs.append(dict(error='summary_precedes_final_result'))
    save(attempt/'diffs.json',diffs)
    evidence=dict(measurement_start_ticks=origin,expected_scopes=len(ref),observed_scopes=len(actual),checked_raw=sum(int(r['checked_records']) for r in actual),
                  checked_windows=sum(int(r['checked_windows']) for r in actual),expected_raw=sum(int(r['checked_records']) for r in expected),
                  expected_windows=sum(int(r['checked_windows']) for r in expected),episode_records=len(episodes),phase_records=len(phases),
                  report_conclusions=dict(metrics),summary=summaries,difference_count=len(diffs))
    save(attempt/'verification.json',evidence)
    return not diffs,evidence

def run(s,output,force=False):
    if hasattr(s,'budget_seconds'):
        from bounded import run_bounded
        return run_bounded(s,output,force)
    stamp=datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S')+'-'+str(os.getpid())
    attempt=output/'runs'/s.name/stamp;attempt.mkdir(parents=True)
    generate(s,attempt)
    inputs=[p for p in sorted((REPO/'rtl').rglob('*')) if p.is_file()]+sorted(HERE.glob('*.py'))+[HERE/'tb_scale_tracer.sv']
    inventory={str(p.relative_to(REPO)):sha(p) for p in inputs}
    gen=[attempt/n for n in ('input_pkg.sv','checker.sv','tb_bw_scale.sv')]
    digest=hashlib.sha256(json.dumps(inventory,sort_keys=True).encode()+b''.join(p.read_bytes() for p in gen)).hexdigest()
    build=output/'builds'/digest;build.mkdir(parents=True,exist_ok=True)
    consumed=build/'source';consumed.mkdir(exist_ok=True)
    for source in inputs:
        target=consumed/source.relative_to(REPO);target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists():
            if sha(target)!=inventory[str(source.relative_to(REPO))]:raise RuntimeError('immutable source snapshot differs: '+str(target))
        else:shutil.copyfile(str(source),str(target))
    manifest=dict(scenario=s.name,configuration=s.manifest(),source_head=capture(['git','rev-parse','HEAD']),source_tree=capture(['git','rev-parse','HEAD^{tree}']),
                  source_status=capture(['git','status','--short']),source_sha256=inventory,generated_sha256={p.name:sha(p) for p in gen},
                  input_sha256=sha(attempt/'input.json'),cfg_sha256=sha(attempt/'expect.cfg'),expected_sha256=sha(attempt/'expected.csv'),
                  compile_digest=digest,source_snapshot=str(consumed),started_utc=utc(),state='PREPARED',waveform=False,memory_or_speed_acceptance_cap=None,
                  host=dict(uname=capture(['uname','-a']),memory=capture(['free','-m']),cpus=capture(['getconf','_NPROCESSORS_ONLN'])),
                  tools=dict(python=sys.version,vcs=capture(['vcs','-ID']),time=capture(['/usr/bin/time','--version'])))
    manifest_path=attempt/'manifest.json';save(manifest_path,manifest)
    cache=build/'compile-success.json'
    if force or not cache.exists() or not (build/'simv').exists():
        rtl=consumed/'rtl'
        for p in gen:shutil.copyfile(str(p),str(build/p.name))
        sources=sorted(rtl.glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))
        sources+=sorted(rtl.glob('*.c'))
        vcs_include=Path(shutil.which('vcs')).resolve().parents[1]/'include'
        n=len(list(build.glob('compile-attempt-*')))+1;compile_dir=build/('compile-attempt-'+str(n));compile_dir.mkdir()
        cmd=['vcs','-full64','-sverilog','-timescale=1ns/1fs','+vpi','-debug_access','-CFLAGS','-I'+str(vcs_include),'+incdir+'+str(rtl),'-assert','svaext','-top','tb_bw_scale','-o',str(build/'simv')]
        cmd+=list(map(str,sources))+[str(build/p.name) for p in gen]
        print('COMPILE '+s.name+' '+str(compile_dir),flush=True)
        result=execute(cmd,build,compile_dir/'compile.log',compile_dir/'time-v.txt',manifest_path,manifest,'compile')
        text=(compile_dir/'compile.log').read_text()
        if result['returncode'] or re.search(r'(?:Warning|Error)-\[',text):
            manifest['state']='COMPILE_FAILED';save(manifest_path,manifest);print('FAIL compile '+str(manifest_path),flush=True);return False
        save(cache,dict(digest=digest,result=result,binary_sha256=sha(build/'simv')))
    else:
        cached=json.loads(cache.read_text());manifest['compile_reused']=True;manifest['compile']=cached['result'];save(manifest_path,manifest)
    cmd=[str(build/'simv'),'-no_save','+VARIANT='+s.variant,'+ACTUAL='+str(attempt/'actual.csv'),'+BW_EXPECT='+str(attempt/'expect.cfg')]
    print('SIMULATE '+s.name+' '+str(attempt),flush=True)
    result=execute(cmd,build,attempt/'simulation.log',attempt/'simulation.time-v.txt',manifest_path,manifest,'simulation')
    passed,evidence=verify(s,attempt)
    passed=passed and result['returncode']==0 and result['state']=='COMPLETED'
    manifest.update(state='VERIFIED' if passed else 'VERIFICATION_FAILED',checked_pass=passed,finished_utc=utc(),verification=evidence,
                    evidence_sha256={p.name:sha(p) for p in attempt.iterdir() if p.is_file() and p.name!='manifest.json'})
    save(manifest_path,manifest)
    latest=output/(s.name+'-latest.json');save(latest,dict(manifest=str(manifest_path),checked_pass=passed))
    print(('PASS ' if passed else 'FAIL ')+s.name+' '+json.dumps(dict(evidence=evidence,sim_peak_rss_kib=result.get('time_v_peak_rss_kib'),manifest=str(manifest_path))),flush=True)
    return passed

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('profiles',nargs='*',choices=list(PROFILES))
    p.add_argument('--output-root',type=Path,default=REPO/'.build/scale')
    p.add_argument('--force-compile',action='store_true')
    p.add_argument('--topology',choices=['common','max'])
    p.add_argument('--width',type=int);p.add_argument('--stride',type=int)
    p.add_argument('--duration-ns',type=int);p.add_argument('--roots',type=int)
    args=p.parse_args()
    if not args.profiles:p.print_help();return 0
    passed=True
    for profile in args.profiles:
        s=Scenario(profile,topology=args.topology,width=args.width,stride=args.stride,duration_ns=args.duration_ns,roots=args.roots)
        if not run(s,args.output_root.resolve(),args.force_compile):passed=False;break
    return not passed
if __name__=='__main__':sys.exit(main())
