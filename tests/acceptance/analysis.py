"""Raw-derived episode and exact-window statistical references (no monitor imports)."""
import math,re
from fractions import Fraction
from model import TICKS,LEAVES,own_reset

def packets(log,prefix):
 return [dict(re.findall(r'(\w+)=([^\s]+)',line)) for line in log.splitlines() if line.startswith(prefix+' ')]

def interval_quality(c,name,frames,a,b):
 data=[f for f in frames if a<=f['t']<b]
 physical_unknown=c['scene']=='reset_unknown' and 0 in LEAVES[name] and a<104100000 and b>103900000
 member=(c['scene']=='point_reset' and 0 in LEAVES[name] and a<104100000 and b>103900000) or any(f['reset_points'] for f in data)
 return all(f['bc'] for f in data) and not physical_unknown,all(f['ec'] for f in data) and not physical_unknown,bool(member)

def episode_reference(c,rows,frames):
 clocks=[r[0] for r in rows if r[1]];index={t:i for i,t in enumerate(clocks)};result={}
 for name,data in frames.items():
  reset=own_reset(c['scene'],name);segments=[(0,reset[0],0,3),(reset[1],c['end_ticks'],1,4)] if reset else [(0,c['end_ticks'],0,4)]
  found=[]
  def tail_due(last):
   i=index[last]+1;tail=clocks[i] if i<len(clocks) else None
   if c['basis']=='ns':due=tail+c['Q']*TICKS if tail is not None else None
   else:due=clocks[i+c['Q']] if i+c['Q']<len(clocks) else None
   return tail,due
  def finish(start,last,end,epoch,status,tail):
   known_tail=tail is not None and tail<end if status!=2 else tail is not None
   stop=tail if known_tail else end
   selected=[f for f in data if start<=f['t']<=last]
   bc,ec,member=interval_quality(c,name,data,start,stop)
   value={'epoch':epoch,'id':len(found)+1,'first':start,'last':last,'tail':tail if known_tail else None,'confirm':end,'status':status,'bytes':sum(f['bytes'] for f in selected),'events':sum(f['events'] for f in selected),'bc':bc,'ec':ec,'member':member}
   value['duration']=tail-start if known_tail else None;value['valid']=bool(status==2 and known_tail and bc)
   value['e2e']=Fraction(value['bytes']*TICKS,value['duration']) if value['valid'] else None
   found.append(value)
  for origin,end,epoch,unfinished_status in segments:
   first=last=None
   for f in data:
    if not origin<f['t']<end or f['events']==0:continue
    if last is not None:
     tail,due=tail_due(last)
     if due is not None and due<=f['t']:
      finish(first,last,due,epoch,2,tail);first=last=None
    if first is None:first=f['t']
    last=f['t']
   if first is not None:
    tail,due=tail_due(last)
    finish(first,last,due if due is not None and due<end else end,epoch,2 if due is not None and due<end else unfinished_status,tail)
  result[name]=found
 return result

def sample_set(windows,episode,a,b,all_episodes,frames):
 selected=[];unknown=0
 for w in windows:
  if not a<=w['end']<b or w['end']<=episode['first']:continue
  foreign=any(f['events'] and w['start']<=f['t']<w['end'] and not episode['first']<=f['t']<=episode['last'] for f in frames)
  if not w['full'] or foreign or not w['denom']:continue
  if not w['bc']:unknown+=1
  else:selected.append(w)
 return selected,unknown

def variation(samples):
 values=[w['bw'] for w in samples];n=len(values)
 if not n:return {'n':0}
 mean=sum(values,Fraction(0))/n;variance=sum((x-mean)**2 for x in values)/n;sigma=math.sqrt(float(variance))
 return {'n':n,'mean':float(mean),'min':float(min(values)),'max':float(max(values)),'sigma':sigma,'cv':100*sigma/float(mean) if mean>0 else None}

def phase_reference(c,name,windows,episode):
 evidence=[];current=0;candidate=0;count=0;candidate_time=0;start=confirm=None;fragments=[]
 def close(at,known):
  if current and start is not None:
   cap=episode['tail'] if episode['tail'] is not None else episode['confirm'];end=min(at,cap)
   if end>start:fragments.append({'kind':current,'start':start,'end':end,'confirm':confirm,'known':known})
 for w in windows:
  if w['epoch']!=episode['epoch'] or not episode['first']<w['end']<=episode['confirm']:continue
  eligible=w['full'] and w['bc'] and w['denom']
  if not eligible:
   close(w['end'],True);current=0;start=confirm=None;evidence=[];candidate=count=0;continue
  evidence=(evidence+[w])[-c['N']:];target=0
  if len(evidence)==c['N']:
   span=evidence[-1]['end']-evidence[0]['end'] if c['basis']=='ns' else evidence[-1]['end_cycle']-evidence[0]['end_cycle']
   if span>=(c['span']*TICKS if c['basis']=='ns' else c['span']):
    xs=[Fraction(v['end'],TICKS) for v in evidence];ys=[v['bw'] for v in evidence];xm=sum(xs)/len(xs);ym=sum(ys)/len(ys)
    slope=sum((x-xm)*(y-ym) for x,y in zip(xs,ys))/sum((x-xm)**2 for x in xs)
    delta=float(slope*(xs[-1]-xs[0]));rms=math.sqrt(float(sum((y-ym-slope*(x-xm))**2 for x,y in zip(xs,ys))/len(xs)))
    if abs(delta)<=.01 and rms<=.01:target=2
    elif delta>=5 and rms<=.01:target=1
    elif delta<=-5 and rms<=.01:target=3
  if target==current:candidate=count=0;continue
  if target!=candidate or count==0:candidate=target;count=1;candidate_time=w['end']
  else:count+=1
  if count>=c['K']:
   close(candidate_time,True);current=target;start=candidate_time if target else None;confirm=w['end'] if target else None;candidate=count=0
 close(episode['tail'] if episode['tail'] is not None else episode['confirm'],episode['status']==2)
 return fragments

def verify(c,rows,frames,windows,log):
 episodes=episode_reference(c,rows,frames);ep_packets=packets(log,'BW_EPISODE');ph_packets=packets(log,'BW_PHASE');ph_metrics=packets(log,'BW_PHASE_METRICS');variations=packets(log,'BW_VARIATION');last_steady=packets(log,'BW_LAST_STEADY');checks={'episodes':0,'phases':0,'variations':0}
 def scope_id(name):return ('tb.top.master0.bw' if name=='p0' else 'memory_all' if name=='all_dmc' else {'die0':'die0_dmc','die1':'die1_dmc'}.get(name,name)) if c['example_ids'] else {'die0':'die0_dmc','die1':'die1_dmc'}.get(name,name)
 def same(actual,key,expected):assert int(actual[key])==int(expected),(c['scene'],actual,key,expected)
 def near(actual,key,expected):assert abs(float(actual[key])-float(expected))<1e-8,(c['scene'],actual,key,expected)
 for name,expected_episodes in episodes.items():
  sid=scope_id(name);actual=[x for x in ep_packets if x['scope']==sid];assert len(actual)==len(expected_episodes),(name,'episode count',actual,expected_episodes)
  for a,e in zip(actual,expected_episodes):
   same(a,'scope_kind',not name.startswith('p'))
   for key,value in [('epoch',e['epoch']),('episode',e['id']),('result_seq',e['id']),('status',e['status']),('first_ticks',e['first']),('last_ticks',e['last']),('confirm_ticks',e['confirm']),('bytes',e['bytes']),('events',e['events']),('first_known',1),('last_known',1),('tail_known',e['tail'] is not None),('bytes_complete',e['bc']),('events_complete',e['ec']),('member_reset',e['member']),('e2e_valid',e['valid'])]:same(a,key,value)
   if e['tail'] is not None:same(a,'tail_ticks',e['tail']);same(a,'duration_ticks',e['duration'])
   if e['valid']:near(a,'e2e_gbps',e['e2e'])
   checks['episodes']+=1
   expected_phases=phase_reference(c,name,windows[name],e);actual_phases=[p for p in ph_packets if p['scope']==sid and int(p['episode'])==e['id']]
   assert len(actual_phases)==len(expected_phases),(c['scene'],name,'phase count',actual_phases,expected_phases)
   for a,p in zip(actual_phases,expected_phases):
    same(a,'scope_kind',not name.startswith('p'))
    for key,value in [('kind',p['kind']),('start_ticks',p['start']),('confirm_ticks',p['confirm']),('start_known',1),('end_known',p['known'])]:same(a,key,value)
    if p['known']:same(a,'end_ticks',p['end'])
    metric=next(m for m in ph_metrics if m['scope']==sid and m['result_seq']==a['result_seq'])
    same(metric,'duration_valid',p['known'])
    if p['known']:
     selected=[f for f in frames[name] if p['start']<=f['t']<p['end']];b=sum(f['bytes'] for f in selected);ev=sum(f['events'] for f in selected);bc,ec,member=interval_quality(c,name,frames[name],p['start'],p['end'])
     for k,v in [('bytes',b),('events',ev),('duration_ticks',p['end']-p['start']),('bytes_complete',bc),('events_complete',ec),('member_reset',member),('bandwidth_valid',bc)]:same(metric,k,v)
     if bc:near(metric,'bandwidth_gbps',Fraction(b*TICKS,p['end']-p['start']))
    p['packet']=a;checks['phases']+=1
   # Independent population statistics from exact qualified publication values.
   intervals=[('EPISODE',0,e['first'],e['tail'] if e['tail'] is not None else e['confirm'],e['status']==2)]
   intervals +=[('PHASE',int(p['packet']['phase']),p['start'],p['end'],p['known']) for p in expected_phases]
   for kind,pid,left,right,known in intervals:
    v=next(v for v in variations if v['scope']==sid and int(v['episode'])==e['id'] and v['interval']==kind and int(v['phase'])==pid)
    samples,unknown=sample_set(windows[name],e,left,right,expected_episodes,frames[name]);stats=variation(samples)
    if known:
     same(v,'samples',stats['n']);same(v,'unknown_samples',unknown)
     complete=unknown==0
     for key,valid in [('minmax_valid',complete and stats['n']>=1),('stddev_valid',complete and stats['n']>=2),('cv_valid',complete and stats['n']>=2 and stats.get('mean',0)>0)]:same(v,key,valid)
     if complete and stats['n']:
      for key,sk in [('mean_gbps','mean'),('min_gbps','min'),('max_gbps','max')]:near(v,key,stats[sk])
      if stats['n']>=2:
       near(v,'stddev_gbps',stats['sigma'])
       if stats['cv'] is not None:near(v,'cv_pct',stats['cv'])
    else:
     for key in ['minmax_valid','stddev_valid','cv_valid']:same(v,key,0)
    checks['variations']+=1
   selected=[p for p in expected_phases if p['kind']==2];representative=next(v for v in last_steady if v['scope']==sid and int(v['episode'])==e['id'])
   if e['status']==2:
    same(representative,'found',bool(selected));same(representative,'selection_valid',bool(selected))
    if selected:
     p=selected[-1]
     for key,value in [('start_ticks',p['start']),('end_ticks',p['end']),('phase',int(p['packet']['phase'])),('phase_result_seq',int(p['packet']['result_seq']))]:same(representative,key,value)
   else:same(representative,'selection_valid',0)
 assert checks['episodes']==len(ep_packets) and checks['phases']==len(ph_packets) and checks['variations']==len(variations)
 assert len(last_steady)==len(ep_packets)
 for name in frames:
  seq=[int(x['result_seq']) for x in ph_packets if x['scope']==scope_id(name)]
  assert seq==list(range(1,len(seq)+1)),('phase result identity',name,seq)
 return checks

def verify_reports(c,rows,frames,windows,log,cfg):
 """Compare configured conclusions with independently derived measurements."""
 rules={};owner=None
 for line in cfg.splitlines():
  line=line.split('#',1)[0].strip()
  if not line:continue
  if line.startswith('['):
   kind,sid=line[1:-1].split(None,1);owner=(str(int(kind=='group')),sid);continue
  key,value=line.split('=',1)
  match=re.fullmatch(r'(.+)_(min|max|abs_tol|rel_tol)_(gbps|ns|pct)',key)
  assert match,key
  rules.setdefault((owner,match.group(1)),{})[match.group(2)]=float(value)
 def sid(name):return 'tb.top.master0.bw' if c['example_ids'] and name=='p0' else 'memory_all' if c['example_ids'] and name=='all_dmc' else {'die0':'die0_dmc','die1':'die1_dmc'}.get(name,name)
 episode_data=episode_reference(c,rows,frames);actual=packets(log,'BW_CHECK');phase_data=packets(log,'BW_PHASE');expected=[]
 def measure_variation(name,ep,left,right,known,family):
  samples,unknown=sample_set(windows[name],ep,left,right,episode_data[name],frames[name]);v=variation(samples)
  if not known or unknown:return None
  if family.endswith('window_min'):return v.get('min')
  if family.endswith('window_max'):return v.get('max')
  if v['n']<2:return None
  return v['cv'] if family.endswith('_cv') else v['sigma']
 def add(name,ep,family,record_kind,pid,value,seq):
  owner=(str(int(not name.startswith('p'))),sid(name));rule=rules[(owner,family)]
  if value is None:conclusion='WARNING'
  else:
   value=float(value);a=rule.get('abs_tol',0);r=rule.get('rel_tol',0)/100
   conclusion='FAIL' if (('min' in rule and value<rule['min']-(a+abs(rule['min'])*r)) or ('max' in rule and value>rule['max']+(a+abs(rule['max'])*r))) else 'PASS'
  expected.append((owner,ep['epoch'],ep['id'],family,record_kind,pid,seq,value,conclusion))
 for name,episodes in episode_data.items():
  owner=(str(int(not name.startswith('p'))),sid(name));families=[family for (target,family) in rules if target==owner]
  if not episodes:
   for family in families:add(name,{'epoch':0,'id':0},family,'scope_final',0,None,0)
  for ep in episodes:
   phases=phase_reference(c,name,windows[name],ep)
   for p in phases:
    p['packet']=next(x for x in phase_data if x['scope']==sid(name) and int(x['episode'])==ep['id'] and int(x['kind'])==p['kind'] and int(x['start_ticks'])==p['start'])
   steady=[p for p in phases if p['kind']==2];selected=steady[-1] if ep['status']==2 and steady else None
   for family in families:
    if family in ['ramp_time','fall_time']:
     applicable=[p for p in phases if p['kind']==(1 if family=='ramp_time' else 3)]
     if not applicable:add(name,ep,family,'episode',0,None,ep['id'])
     for p in applicable:add(name,ep,family,'phase',int(p['packet']['phase']),Fraction(p['end']-p['start'],TICKS) if p['known'] else None,int(p['packet']['result_seq']))
    elif family=='e2e_bw':add(name,ep,family,'episode',0,ep['e2e'],ep['id'])
    elif family.startswith('episode_'):
     value=measure_variation(name,ep,ep['first'],ep['tail'] if ep['tail'] is not None else ep['confirm'],ep['status']==2,family)
     add(name,ep,family,'episode',0,value,ep['id'])
    elif family.startswith('steady_'):
     value=None;pid=0
     if selected:
      p=selected;pid=int(p['packet']['phase'])
      if family=='steady_bw':
       bc,ec,member=interval_quality(c,name,frames[name],p['start'],p['end'])
       if p['known'] and bc:value=Fraction(sum(f['bytes'] for f in frames[name] if p['start']<=f['t']<p['end'])*TICKS,p['end']-p['start'])
      else:value=measure_variation(name,ep,p['start'],p['end'],p['known'],family)
     # Unavailable selected identity may still carry an original phase; do not
     # invent that numeric identity as measurement evidence.
     add(name,ep,family,'last_steady',pid,value,ep['id'])
 assert len(actual)==len(expected),('configured report count',c['scene'],len(actual),len(expected))
 used=set();counts={'PASS':0,'FAIL':0,'WARNING':0}
 for owner,epoch,eid,family,record_kind,pid,seq,value,conclusion in expected:
  matches=[(i,x) for i,x in enumerate(actual) if i not in used and (x['scope_kind'],x['scope'])==owner and int(x['epoch'])==epoch and int(x['episode'])==eid and x['metric']==family and x['kind']==record_kind and int(x['result_seq'])==seq and (int(x['phase'])==pid or (value is None and record_kind=='last_steady'))]
  assert len(matches)==1,('missing/duplicate report',c['scene'],owner,epoch,eid,family,matches)
  i,x=matches[0];used.add(i);assert x['conclusion']==conclusion,('report verdict',c['scene'],x,value,conclusion)
  if value is None:assert x['actual']=='UNAVAILABLE',x
  else:assert abs(float(x['actual'])-value)<1e-8,('report actual',x,value)
  counts[conclusion]+=1
 identities=[tuple(x[k] for k in ['scope_kind','scope','epoch','episode','result_seq','kind','phase','metric']) for x in actual]
 assert len(identities)==len(set(identities)),('duplicate metric settlement',identities)
 summaries=packets(log,'BW_SUMMARY');assert len(summaries)==1
 summary=summaries[0]
 for key,label in [('pass','PASS'),('fail','FAIL'),('warning','WARNING')]:assert int(summary[key])==counts[label]
 status='FAIL' if counts['FAIL'] else 'WARNING' if counts['WARNING'] else 'PASS' if counts['PASS'] else 'STATISTICS_ONLY'
 assert summary['status']==status and int(summary['scopes_done'])==int(summary['scopes_expected'])==16
 lines=log.splitlines();last_summary=max(i for i,x in enumerate(lines) if x.startswith('BW_SUMMARY '))
 assert all(i<last_summary for i,x in enumerate(lines) if x.startswith(('BW_PHASE ','BW_EPISODE ','BW_CHECK ')))
 return {'expected':counts,'summary_status':status}
