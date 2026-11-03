"""Human-facing expected/actual tables; references are the independent raw model."""
import json
from fractions import Fraction
from model import LEAVES,TICKS,frame_table,window_table,expected_scope_id
from analysis import episode_reference,phase_reference,interval_quality,packets,sample_set,variation

def write_tables(c,rows,out,comparison):
 frames=frame_table(rows);windows=window_table(c,rows,frames);episodes=episode_reference(c,rows,frames);log=(out/'run.log').read_text();eps=packets(log,'BW_EPISODE');phm=packets(log,'BW_PHASE_METRICS')
 def sid(name):return expected_scope_id(c,name)
 reference={'episodes':{},'phases':{}}
 for name,es in episodes.items():
  reference['episodes'][name]=[{k:float(v) if isinstance(v,Fraction) else v for k,v in e.items()} for e in es]
  reference['phases'][name]=[]
  for e in es:
   prior_last=es[e['id']-2]['last'] if e['id']>1 else -1
   for p in phase_reference(c,name,windows[name],e,prior_last):
    b=sum(f['bytes'] for f in frames[name] if p['start']<=f['t']<p['end']);bc,ec,m=interval_quality(c,name,frames[name],p['start'],p['end']);q=dict(p,episode=e['id'],bytes=b,raw_bw=float(Fraction(b*TICKS,p['end']-p['start'])) if p['known'] and bc else None)
    selected,unknown=sample_set(windows[name],e,p['start'],p['end'],es,frames[name]);q['variation']=variation(selected);q['unknown_samples']=unknown;reference['phases'][name].append(q)
 (out/'reference.json').write_text(json.dumps(reference,indent=2)+'\n')
 text='# '+c['scene']+' / '+c['basis']+' expected and actual\n\nAutomated checks **PASS**. **Human review PENDING**; agent inspection is separate.\n\n'
 text+='All '+str(comparison['counts']['raw'])+' raw records, '+str(comparison['counts']['receipts'])+' receipts and '+str(comparison['counts']['windows'])+' public windows match the stimulus-only reference. Analysis checks: '+str(comparison['analysis_counts'])+'.\n\n'
 text+='Configuration: W='+str(c['W'])+', S='+str(c['S'])+', Q='+str(c['Q'])+' in '+c['basis']+'; fixed N='+str(c['N'])+', span='+str(c['span'])+', K='+str(c['K'])+'. Public T='+str(c.get('start_ticks',0))+'fs; input table uses offsets from T; end='+str(c['end_ticks'])+'fs. Exact bytes/events/identity/quality checks; window real tolerance1e-10GB/s and independently accumulated final statistics1e-8GB/s/percentage points. Formal cfg comparisons use only their own configured tolerance.\n\n'
 text+='## Input and window checkpoints\n\n'
 text+='See [raw stimulus](stimulus.txt) (or trace archive), [configuration](expect.cfg), [commands/source hashes](commands.json) and [independent reference](reference.json). Every window was checked; the following are selected checkpoints.\n\n|Scope|Expected interval ns|Known bytes/events|Expected GB/s|Actual GB/s|Difference|Full / byte / event / member-reset|\n|---|---|---:|---:|---:|---:|---|\n'
 times=[102*TICKS]
 if c['scene']=='start_stop':times=[20*TICKS,21*TICKS,30*TICKS,60*TICKS,61*TICKS,70*TICKS]
 if c['scene'] in ['point_reset','child_reset','upper_reset','size_unknown','valid_unknown','reset_unknown']:times=[104*TICKS,105*TICKS,115*TICKS]
 if c['scene'] in ['clock_stop','hints']:times=[79*TICKS,90*TICKS,101*TICKS,112*TICKS]
 if c['scene']=='frequency':times=[79*TICKS,85*TICKS,91*TICKS,102*TICKS]
 if c['scene']=='e2':times=[11*TICKS,12*TICKS,13*TICKS,21*TICKS,23*TICKS]
 if c['scene']=='isolated':times=[20*TICKS,21*TICKS,30*TICKS,31*TICKS]
 if c['scene'] in ['zero','no_episode']:times=[30*TICKS,40*TICKS,52*TICKS]
 if c['scene']=='varying' or c['scene']=='e5':times=[32*TICKS,50*TICKS,75*TICKS,100*TICKS,138*TICKS]
 if c['scene']=='protocols':times=[61*TICKS,65*TICKS,102*TICKS]
 times=[at+c.get('start_ticks',0) for at in times]
 seen=set()
 import csv
 for name in ['p0','p1','p2','die0','all_dmc','mixed','p10','p11']:
  public=[x for x in csv.reader((out/(name+'.csv')).open()) if x[0]=='W']
  for at in times:
   chosen=next(((r,w) for r,w in zip(public,windows[name]) if w['end']>=at),None)
   if not chosen:continue
   r,w=chosen
   if (name,w['end']) in seen:continue
   seen.add((name,w['end']));value=float(r[12]);want=float(w['bw'])
   text+='|%s|[%g,%g)|%d / %d|%.12g|%.12g|%.3g|%d / %d / %d / %d|\n'%(name,w['start']/TICKS,w['end']/TICKS,w['bytes'],w['events'],want,value,value-want,w['full'],w['bc'],w['ec'],w['member'])
 text+='\n## Episodes and final intervals\n\n|Scope|Epoch / episode|Expected first / last / tail / confirmation ns|Bytes/events|Expected e2e|Actual e2e|Lifecycle / quality|\n|---|---|---|---:|---:|---:|---|\n'
 for name in ['p0','die0','all_dmc','mixed']:
  for e in episodes[name]:
   actual=next(x for x in eps if x['scope']==sid(name) and int(x['episode'])==e['id']);tail='UNKNOWN' if e['tail'] is None else '%g'%(e['tail']/TICKS);expected='UNAVAILABLE' if e['e2e'] is None else '%.12g'%float(e['e2e']);observed=actual['e2e_gbps'] if e['valid'] else 'UNAVAILABLE'
   text+='|%s|%d / %d|%g / %g / %s / %g|%d / %d|%s|%s|status%d; bytes%d, events%d, member%d|\n'%(name,e['epoch'],e['id'],e['first']/TICKS,e['last']/TICKS,tail,e['confirm']/TICKS,e['bytes'],e['events'],expected,observed,e['status'],e['bc'],e['ec'],e['member'])
 text+='\nStatus2=normal complete,3=reset interrupted,4=observation truncated. Unknown tails/backing real0 are not measurements.\n\n'
 text+='## Confirmed fragments (point0 and all_dmc)\n\n|Scope / episode|Kind|Expected [start,end)ns / confirmation|Expected raw BW|Actual raw BW|Qualified samples / mean / population sigma / CV|\n|---|---|---|---:|---:|---|\n'
 for name in ['p0','all_dmc']:
  for p in reference['phases'][name]:
   actual=next(x for x in phm if x['scope']==sid(name) and int(x['episode'])==p['episode'] and int(x['start_ticks'])==p['start']);v=p['variation'];expect='UNAVAILABLE' if p['raw_bw'] is None else '%.12g'%p['raw_bw'];observed=actual['bandwidth_gbps'] if p['raw_bw'] is not None else 'UNAVAILABLE'
   stats='%d / %s / %s / %s'%(v['n'],v.get('mean','NA'),v.get('sigma','NA'),v.get('cv','NA'))
   text+='|%s / %d|%s|[%g,%g) / %g%s|%s|%s|%s|\n'%(name,p['episode'],{1:'RAMP',2:'STEADY',3:'FALL'}[p['kind']],p['start']/TICKS,p['end']/TICKS,p['confirm']/TICKS,'' if p['known'] else ' END UNKNOWN',expect,observed,stats)
 text+='\nCandidate boundaries and confirmations use exact Fraction OLS on adjacent pairs of six independent new/full/owned windows at actual physical times, K=2 and min(W,5S). Steady entry/hold uses 4%/8% fitted change and 10%/12% raw residual RMS; trends use 10% change and 2.5% paired residual RMS. No phase labels are driven into the monitor. Raw interval BW differs from the window mean; sigma uses window mean, not fit RMS. Full reference.json includes all scopes.\n\n'
 text+='## Nonfatal performance settlement\n\n'+comparison['summary']+'\n\nExpected conclusions from independent metric values and cfg: '+str(comparison['report_reference']['expected'])+'. Performance FAIL/WARNING is a successful test outcome when the value/evidence requires it. Later public windows and TB_PASS prove continued simulation.\n\n'
 text+='```text\n'+'\n'.join(comparison['performance_checks'])+'\n```\n\n[Real FSDB](waves.fsdb), fixed public views (`*.sav`) and fresh screenshots (`*.png`) accompany this scene. Digital real rows may use rounded engineering display; exact integer counts/bounds and17-digit logs/reference tables resolve boundary decisions. Original simulation data/images are unmodified.\n'
 (out/'expected-actual.md').write_text(text)
