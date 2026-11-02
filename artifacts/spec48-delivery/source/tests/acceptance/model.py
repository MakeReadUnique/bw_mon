"""Independent acceptance references from raw bus rows and exact clock timestamps.

This module never imports monitor code or observed outputs. Fraction arithmetic
keeps byte/time expectations exact until comparison with displayed real values.
"""
from fractions import Fraction
TICKS=1000000
LEAVES={'p'+str(p):[p] for p in range(12)}
LEAVES.update(die0=list(range(4)),die1=list(range(4,8)),all_dmc=list(range(8)),mixed=[0,1,2,3,8,9])
PRIMARY=['protocols','steady','start_stop','varying','point_reset','child_reset','upper_reset','size_unknown','valid_unknown','reset_unknown','clock_stop','frequency','hints','zero','no_episode','truncated','isolated','e2']
SUPPLEMENTAL=['e3_boundary','e3_delayed','e3_delayed_fixed','e4_boundary','e4_below','e4_low','e5']

def require_scene_inventory(configurations):
 names=[c['scene']+'_'+c['basis'] for c in configurations]
 current={s+'_'+b for s in PRIMARY for b in ('ns','cycle')} | {s+'_ns' for s in SUPPLEMENTAL}
 historical=current-{'e3_delayed_fixed_ns'}
 assert len(names)==len(set(names)), 'duplicate scene identity'
 if all(c['N']==6 for c in configurations):assert set(names)==current, 'incomplete fixed-policy matrix'
 else:assert set(names) in (historical,current), 'incomplete historical/mixed matrix'
 return len(names)

def expected_scope_id(c,name):
 if c['example_ids'] and name=='p0':return 'tb.top.master0.bw'
 if c['example_ids'] and name=='all_dmc':return 'memory_all'
 return {'die0':'die0_dmc','die1':'die1_dmc'}.get(name,name)

def configuration(scene,basis):
 c={'scene':scene,'basis':basis,'W':10 if basis=='ns' else 20,'S':1 if basis=='ns' else 2,'Q':12 if basis=='ns' else 24,'N':6,'K':2,'end_ticks':160*TICKS+1,'top':'tb_acceptance_'+basis,'example_ids':False}
 if scene in ['start_stop']:c['end_ticks']=100*TICKS+1
 if scene in ['varying','e5']:c['end_ticks']=180*TICKS+1
 if scene in ['zero','no_episode','isolated']:c['end_ticks']=60*TICKS+1
 if scene=='truncated':c['end_ticks']=110*TICKS+1
 if scene=='e2':c['end_ticks']=40*TICKS+1
 if scene.startswith('e4_'):c['end_ticks']=130*TICKS+1
 if scene=='e3_boundary':c.update(top='tb_acceptance_e3_boundary',Q=30,end_ticks=170*TICKS+1)
 if scene.startswith('e3_delayed'):c.update(top='tb_acceptance_e3_delayed',W=100,S=10,Q=60,end_ticks=(216 if scene=='e3_delayed_fixed' else 196)*TICKS+1)
 if scene=='e5':c.update(top='tb_acceptance_e5',example_ids=True)
 c['span']=min(c['W'],5*c['S'])
 return c

def at_measurement_start(c,rows,start):
 """Translate original relative inputs by the public T, without changing them."""
 if start<=0:raise ValueError('ready must publish a positive measurement start')
 shifted=dict(c,start_ticks=start,end_ticks=c['end_ticks']+start)
 return shifted,[[row[0]+start]+row[1:] for row in rows]

def controls(scene,t):
 # Known defaults; selected faults occupy their own independent scene only.
 reset=4095;reset_x=size_x=valid_x=0;child=parent=1
 if 103900000<=t<104100000:
  if scene=='point_reset':reset &=~1
  if scene=='reset_unknown':reset_x=1
  if scene=='size_unknown':size_x=1
  if scene=='valid_unknown':valid_x=1
  if scene=='child_reset':child=0
  if scene=='upper_reset':parent=0
 return reset,reset_x,size_x,valid_x,child,parent

def stimulus(c):
 scene=c['scene'];end=c['end_ticks'];edges=list(range(500000,end-1,500000))
 if scene in ['clock_stop','hints']:edges=[t for t in edges if not 80*TICKS<=t<=100*TICKS]
 if scene=='frequency':edges=list(range(500000,80*TICKS,500000))+list(range(80500000,end-1,TICKS))
 if scene.startswith('e4_') or scene.startswith('e3_delayed'):edges=list(range(TICKS,end-1,TICKS))
 if scene=='e3_boundary':edges=list(range(80*TICKS,104*TICKS,2*TICKS))+list(range(132*TICKS,end-1,2*TICKS))
 extra=[]
 if scene in ['point_reset','child_reset','upper_reset','size_unknown','valid_unknown','reset_unknown']:extra=[103900000,104100000]
 if scene=='hints':extra=[85*TICKS,95*TICKS]
 rows=[]
 e2={t*TICKS:b for t,b in zip([1,3,5,Fraction(17,2),11,13,17,21],[64,64,128,64,128,64,64,128])}
 for t,edge in sorted([(t,1) for t in edges]+[(t,0) for t in extra]):
  amount=[64]*12;active=4095 if t<120*TICKS else 0;ready=4095
  if scene=='start_stop':active=4095 if 20*TICKS<=t<60*TICKS else 0
  if scene in ['varying','e5']:
   n=Fraction(t,TICKS);on=False
   if 20<=n<60:
    on=True
    amount=[min(64,4*(1+int(n-20)))]*12
   elif 60<=n<80 or 108<=n<124:on=(t//500000)%2==0
   elif 88<=n<108 or 124<=n<140:on=True
   active=4095 if on else 0
  if scene=='zero':active=1 if 20*TICKS<=t<40*TICKS else 0;amount[0]=0
  if scene=='no_episode':active=0
  if scene=='isolated':active=1 if t==20*TICKS else 0
  if scene=='e2':active=1 if t in e2 else 0;amount[0]=e2.get(t,64)
  if scene=='e3_boundary':active=1 if t in [80*TICKS,84*TICKS,100*TICKS,132*TICKS] else 0;amount[0]=128 if t in [84*TICKS,132*TICKS] else 64
  if scene=='e3_delayed':active=1 if t in [95*TICKS,135*TICKS] else 0;amount[0]=640 if t==95*TICKS else 0
  if scene=='e3_delayed_fixed':active=1 if t in [95*TICKS,155*TICKS] else 0;amount[0]=640 if t==95*TICKS else 0
  if scene.startswith('e4_'):
   active=1 if TICKS<=t<=100*TICKS else 0
   amount[0]=128 if scene=='e4_low' else 151 if scene=='e4_below' and t==50*TICKS else 152
  if scene=='hints' and 85*TICKS<=t<95*TICKS:active|=2;ready&=~2
  reset,rx,sx,vx,child,parent=controls(scene,t)
  credit_returns=active
  if scene=='protocols':
   if 60*TICKS<=t<64*TICKS:ready &=~2
   if 60*TICKS<=t<62*TICKS:credit_returns &=~4
   if t==61*TICKS:vx=2
  # The unused valid pin is deliberately0 on credit links: flitv alone counts.
  valid=active & ~0x924
  rows.append([t,edge,valid,active,ready,credit_returns,reset,rx,sx,vx,child,parent]+amount)
 return rows

def frame_table(rows):
 frames={name:[] for name in LEAVES};k=0
 for row in rows:
  t,edge,active,flits,ready,returns,reset,rx,sx,vx,child,parent=row[:12]
  if not edge:continue
  k+=1;points=[]
  for p in range(12):
   r='x' if rx&(1<<p) else str((reset>>p)&1)
   bc=ec=True;b=e=rp=0
   if r=='0':rp=1
   elif r=='x':bc=ec=False
   else:
    send=bool(flits&(1<<p)) if p%3==2 else None if vx&(1<<p) else bool(active&(1<<p))
    if p%3==1 and not ready&(1<<p):send=False
    if send is None:bc=ec=False
    elif send:
     e=1
     if p%2==0 and sx&(1<<p):bc=False
     else:b=row[12+p] if p%2==0 else 64
   source_epoch=int(any(x[0]<=t and not (x[6]&(1<<p)) for x in rows if not x[1]))
   points.append({'t':t,'k':k,'bytes':b,'events':e,'bc':bc,'ec':ec,'reset_points':rp,'reset_n':r,'source_epoch':source_epoch})
  for name,leaves in LEAVES.items():
   f={'t':t,'k':k,'bytes':sum(points[p]['bytes'] for p in leaves),'events':sum(points[p]['events'] for p in leaves),'bc':all(points[p]['bc'] for p in leaves),'ec':all(points[p]['ec'] for p in leaves),'reset_points':sum(points[p]['reset_points'] for p in leaves),'reset_n':points[leaves[0]]['reset_n'] if name.startswith('p') else '1','source_epoch':points[leaves[0]]['source_epoch'] if name.startswith('p') else 0}
   frames[name].append(f)
 return frames

def own_reset(scene,name,start=0):
 return (start+103900000,start+104100000) if ((scene=='point_reset' and name=='p0') or (scene=='child_reset' and name=='die0') or (scene=='upper_reset' and name=='all_dmc')) else None

def window_table(c,rows,frames):
 result={};clocks=[r[0] for r in rows if r[1]];start=c.get('start_ticks',0)
 for name,leaves in LEAVES.items():
  reset=own_reset(c['scene'],name,start);segments=[(start,reset[0],0),(reset[1],c['end_ticks'],1)] if reset else [(start,c['end_ticks'],0)]
  windows=[];sequence=0
  for origin,end,epoch in segments:
   scheduled=[]
   if c['basis']=='ns':
    scheduled=[(t,max(origin,t-c['W']*TICKS),0,0,0,t-origin>=c['W']*TICKS) for t in range(origin+c['S']*TICKS,end,c['S']*TICKS)]
   else:
    actual=[(k+1,t) for k,t in enumerate(clocks) if origin<t<end or (origin==0 and t==0)]
    for j in range(c['S'],len(actual),c['S']):
     left=max(0,j-c['W']);scheduled.append((actual[j][1],actual[left][1],actual[left][0],actual[j][0],j-left,j>=c['W']))
   for t,left,lc,rc,cc,full in scheduled:
    selected=[f for f in frames[name] if left<=f['t']<t];b=sum(f['bytes'] for f in selected);e=sum(f['events'] for f in selected)
    unknown=c['scene']=='reset_unknown' and 0 in leaves and left<start+104100000 and t>start+103900000
    member=(c['scene']=='point_reset' and 0 in leaves and left<start+104100000 and t>start+103900000) or any(f['reset_points'] for f in selected)
    bc=all(f['bc'] for f in selected) and not unknown;ec=all(f['ec'] for f in selected) and not unknown
    sequence+=1
    windows.append({'seq':sequence,'epoch':epoch,'start':left,'end':t,'start_cycle':lc,'end_cycle':rc,'coverage':t-left,'cycles':cc,'bytes':b,'events':e,'bw':Fraction(b*TICKS,t-left),'bpc':Fraction(b,cc) if cc else Fraction(0),'full':full,'warm':not full,'bc':bc,'ec':ec,'denom':True,'member':bool(member),'valid':bool(full and bc)})
  result[name]=windows
 return result


def expectations(c):
 scene=c['scene']
 if scene.startswith('e4_'):
  return "[point p0]\ne2e_bw_min_gbps=160\ne2e_bw_rel_tol_pct=5\n"
 if scene=='e5':
  return "[point tb.top.master0.bw]\nsteady_bw_min_gbps=80\nsteady_bw_rel_tol_pct=5\ne2e_bw_min_gbps=60\nramp_time_max_ns=30\nsteady_cv_max_pct=5\n[group memory_all]\nsteady_bw_min_gbps=160\nepisode_cv_max_pct=10\n"
 if scene.startswith('e3_delayed'):
  return "[point p0]\nsteady_bw_max_gbps=0\nsteady_window_min_min_gbps=6.4\n[group all_dmc]\nsteady_bw_max_gbps=0\nsteady_window_min_min_gbps=6.4\n"
 if scene=='varying':
  return ''.join('[%s]\ne2e_bw_min_gbps=0\nsteady_bw_min_gbps=%d\nepisode_cv_max_pct=10\nramp_time_max_ns=30\nfall_time_max_ns=30\n'%(scope,bw) for scope,bw in [('point p0',128),('group all_dmc',1024)])
 if scene=='zero':
  return ''.join('[%s]\ne2e_bw_min_gbps=0\nsteady_bw_min_gbps=0\nepisode_stddev_max_gbps=0\nepisode_cv_max_pct=0\n'%scope for scope in ['point p0','group all_dmc'])
 if scene in ['no_episode','truncated','isolated','e2','e3_boundary']:
  return "[point p0]\ne2e_bw_min_gbps=0\n[group all_dmc]\ne2e_bw_min_gbps=0\n"
 return "[point p0]\ne2e_bw_min_gbps=160\ne2e_bw_rel_tol_pct=5\n[group die0_dmc]\ne2e_bw_min_gbps=512\n[group all_dmc]\ne2e_bw_min_gbps=1024\nsteady_bw_min_gbps=1024\nepisode_cv_max_pct=10\n"
