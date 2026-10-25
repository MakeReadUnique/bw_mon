#!/usr/bin/env python3
"""Observe admitted MAX jobs; launch only profiles explicitly allowed by root."""
import datetime,hashlib,json,os,pathlib,re,subprocess,sys,time
BASE=pathlib.Path('/tmp/bw-mon-spec13-resume/max30-final-complete-campaign')
PROFILES=('max-ns','max-cycle','max-ns-short-unknown','max-cycle-short-reset')
PRODUCTION=json.loads(pathlib.Path('/tmp/bw-mon-spec13-resume/review-fix-evidence/production-milestone.json').read_text())['production_sha256']
def utc():return datetime.datetime.utcnow().isoformat()+'Z'
def save(path,obj):
 tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n');tmp.replace(path)
def process(pid):
 try:
  text=(pathlib.Path('/proc')/str(pid)/'status').read_text();state=re.search(r'^State:\s+(\S+)',text,re.M).group(1);match=re.search(r'^VmRSS:\s+(\d+)',text,re.M);stat=(pathlib.Path('/proc')/str(pid)/'stat').read_text().split()
  return dict(pid=pid,state=state,rss_kib=int(match.group(1)) if match else 0,cpu_seconds=(int(stat[13])+int(stat[14]))/os.sysconf('SC_CLK_TCK'))
 except (OSError,AttributeError,IndexError):return None
def observe(profile):
 rp=BASE/(profile+'-launch.json')
 if not rp.exists():return dict(profile=profile,state='UNPREPARED',active=False)
 r=json.loads(rp.read_text());row=dict(profile=profile,state=r['state'],active=bool(r.get('runner_pid')),runner_pid=r.get('runner_pid'),receipt=str(rp),output_root=r['output_root'])
 paths=sorted(pathlib.Path(r['output_root']).glob('runs/*/*/manifest.json'))
 if paths:
  mp=paths[-1];m=json.loads(mp.read_text());row.update(state=m['state'],manifest=str(mp),active=m['state'] not in ('VERIFIED','VERIFICATION_FAILED','COMPILE_FAILED'))
  if 'simulation' in m:
   wrapper=m['simulation'].get('pid');row['simulation_wrapper_pid']=wrapper
   for d in pathlib.Path('/proc').iterdir():
    if not d.name.isdigit():continue
    try:
     text=(d/'status').read_text();parent=int(re.search(r'^PPid:\s+(\d+)',text,re.M).group(1))
     if parent==wrapper:row['simulator']=process(int(d.name))
    except (OSError,AttributeError):pass
   log=mp.parent/'simulation.log'
   if log.exists():
    text=log.read_text(errors='replace');lines=text.splitlines();row['ready']=[l for l in lines if l.startswith(('BW_READY ','SCALE_RUN_START '))][-2:];row['progress']=[l for l in lines if l.startswith('SCALE_PROGRESS ')][-1:];row['fatal_or_mismatch_count']=len(re.findall(r'Fatal:|BW_CORE_ERROR|SCALE_\w*MISMATCH|Error-\[',text))
  if 'verification' in m:row['verification']=m['verification'];row['checked_pass']=m.get('checked_pass')
 if row['active']:
  current=process(r.get('runner_pid',0))
  if not current or current['state']=='Z':row.update(state='RUNNER_MISSING_BEFORE_VERIFICATION',active=False)
 return row
while True:
 gate=json.loads((BASE/'admission.json').read_text());rows=[observe(p) for p in PROFILES]
 failures=[r for r in rows if r['state'] in ('VERIFICATION_FAILED','COMPILE_FAILED','RUNNER_MISSING_BEFORE_VERIFICATION') or r.get('fatal_or_mismatch_count',0)]
 source_equal=all(hashlib.sha256((pathlib.Path('/home/eda/bw_cal')/name).read_bytes()).hexdigest()==expected for name,expected in PRODUCTION.items())
 active=sum(r['active'] for r in rows);allowed=set(gate['allowed_profiles']);assert allowed<=set(PROFILES)
 status=dict(checked_utc=utc(),monitor_pid=os.getpid(),production_runtime='56127495f597d215003000356ac3b5387cc809a1',source_still_current=source_equal,admission=gate,profiles=rows,active_max30=active,state='MONITORING',ticket_complete=False)
 if failures:status.update(state='FAILURE_DETECTED_NO_FURTHER_LAUNCHES',failures=failures)
 elif not source_equal:status.update(state='PRODUCTION_CHANGED_NO_FURTHER_LAUNCHES')
 elif all(r['state']=='VERIFIED' and r.get('checked_pass') for r in rows):status.update(state='FOUR_FULL_RUNNERS_VERIFIED_ARCHIVE_AUDIT_PENDING')
 save(BASE/'monitor-status.json',status)
 with (BASE/'monitor-timeline.jsonl').open('a') as log:log.write(json.dumps(status,sort_keys=True)+'\n')
 if status['state']!='MONITORING':
  print(status['checked_utc'],status['state'],flush=True);break
 if not gate.get('pause_new_launches',False):
  capacity=min(gate['max_active_max30'],max(0,gate['total_heavy_cap']-gate['other_max_reserved']))
  for row in rows:
   if active>=capacity:break
   if row['profile'] in allowed and not row.get('runner_pid'):
    command=[sys.executable,'-B','/tmp/bw-mon-spec13-resume/max30-final-launch.py',row['profile'],'--launch','--nominal-admitted']
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,universal_newlines=True)
    with (BASE/'monitor-launches.log').open('a') as log:log.write(utc()+' '+result.stdout)
    if result.returncode:save(BASE/'monitor-launch-failure.json',dict(checked_utc=utc(),profile=row['profile'],returncode=result.returncode,output=result.stdout));raise SystemExit(1)
    active+=1
 time.sleep(30)
