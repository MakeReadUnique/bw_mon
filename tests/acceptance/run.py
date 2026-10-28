#!/usr/bin/env python3
"""Actual public12-point scenes, exact raw-table oracle, FSDB and durable evidence."""
import argparse,csv,hashlib,json,re,subprocess
from pathlib import Path
from build import prepare,receipt
from evidence import canonical_sha
from model import configuration,stimulus,frame_table,window_table,PRIMARY,SUPPLEMENTAL,LEAVES,TICKS,expectations,expected_scope_id,at_measurement_start
from summarize import write_tables
from analysis import verify as verify_analysis,verify_reports,packets
ROOT=Path(__file__).resolve().parents[2]

def command(cmd,cwd,log):
 with Path(log).open('w') as f:r=subprocess.run([str(x) for x in cmd],cwd=str(cwd),stdout=f,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError('command failed: '+str(log))

def check_trace(c,out,rows):
 origin=c.get('start_ticks',0);frames=frame_table(rows);windows=window_table(c,rows,frames);counts={'raw':0,'windows':0,'receipts':0};checkpoints=[]
 for name in LEAVES:
  data=list(csv.reader((out/(name+'.csv')).open()));actual_id=next(r for r in data if r[0]=='ID')
  expected_id=expected_scope_id(c,name)
  assert actual_id[1:]==[str(int(not name.startswith('p'))),expected_id,name],(name,actual_id)
  records=[r for r in data if r[0]=='R'];receipts=[r for r in data if r[0]=='A'];public=[r for r in data if r[0]=='W']
  assert len(records)==len(frames[name]) and len(receipts)==len(frames[name]),(name,'raw/receipt count')
  for r,f in zip(records,frames[name]):
   wanted=[f['k'],f['source_epoch'],f['t'],f['k'],f['bytes'],f['events'],int(f['bc']),int(f['ec']),f['reset_points']]
   assert [int(x) for x in r[1:10]]==wanted and r[10]==f['reset_n'],(name,'raw',r,wanted)
  for r,f in zip(receipts,frames[name]):assert [int(x) for x in r[1:]]==[f['k'],f['t']],(name,'receipt',r,f)
  assert len(public)==len(windows[name]),(name,'publication count',len(public),len(windows[name]))
  for r,w in zip(public,windows[name]):
   integer=[w[k] for k in ['seq','epoch']]+[None]+[w[k] for k in ['start','end','start_cycle','end_cycle','coverage','cycles','bytes','events']]
   actual=[int(x) for x in r[1:12]]
   assert all(a==b for a,b in zip(actual,integer) if b is not None),(name,'window',r,w)
   assert int(r[3])==w['end'],(name,'publication time',r,w)
   assert abs(float(r[12])-float(w['bw']))<1e-10 and abs(float(r[13])-float(w['bpc']))<1e-10,(name,'real',r,w)
   flags=[int(w[k]) for k in ['full','warm','bc','ec','denom','member','valid']]
   assert [int(x) for x in r[14:]]==flags,(name,'quality',r,w)
  counts['raw']+=len(records);counts['receipts']+=len(receipts);counts['windows']+=len(public)
  chosen=[(r,w) for r,w in zip(public,windows[name]) if origin+102*TICKS<=w['end']<=origin+103*TICKS]
  if chosen:
   r,w=chosen[0];checkpoints.append({'scope':name,'scope_id':expected_id,'start_ticks':w['start'],'end_ticks':w['end'],'bytes':w['bytes'],'events':w['events'],'coverage_ticks':w['coverage'],'expected_gbps':float(w['bw']),'actual_gbps':float(r[12]),'difference':float(r[12])-float(w['bw']),'full':w['full'],'bytes_complete':w['bc'],'events_complete':w['ec']})
 # Literal spec checks supplement the raw-table model, detecting a wrong scene generator.
 if c['scene'] in ['steady','point_reset','child_reset','upper_reset','size_unknown']:
  at104={n:next(f for f in frames[n] if f['t']==origin+104*TICKS) for n in ['die0','all_dmc','mixed']}
  wanted=([192,448,320],[3,7,5]) if c['scene']=='point_reset' else ([192,448,320],[4,8,6]) if c['scene']=='size_unknown' else ([256,512,384],[4,8,6])
  assert [at104[n]['bytes'] for n in at104]==wanted[0] and [at104[n]['events'] for n in at104]==wanted[1],('T5E1',at104)
 if c['scene']=='e2' and c['basis']=='ns':
  for t,b in [(11,320),(12,384),(13,384),(21,256),(23,256)]:assert next(w for w in windows['p0'] if w['end']==origin+t*TICKS)['bytes']==b
 return {'status':'PASS','human_review':'PENDING','counts':counts,'numeric_tolerance_gbps':1e-10,'checks':checkpoints}

def one(scene,basis,cflags="",output_root=None):
 c=configuration(scene,basis);out=(output_root or ROOT/'artifacts/acceptance')/(scene+'_'+basis);out.mkdir(parents=True,exist_ok=True)
 (out/'expect.cfg').write_text(expectations(c))
 rows=stimulus(c);(out/'stimulus.txt').write_text(''.join(' '.join(str(x) for x in row)+'\n' for row in rows))
 top=c['top']
 sources=sorted((ROOT/'rtl').glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))+sorted((ROOT/'rtl').glob('*.c'))+[ROOT/'tests/acceptance/scene.sv']
 build,snapshot,cmd,fingerprint,native_flags=prepare(ROOT,top,sources,cflags)
 digest=canonical_sha(fingerprint);stamp=build/'source.sha256'
 if not stamp.exists() or stamp.read_text()!=digest or not (build/'simv').exists() or not (build/'csrc/bw_slot_settlement.d').exists():
  command(cmd,build,build/'compile.log');assert not re.search(r'(?:Warning|Error)-\[',(build/'compile.log').read_text());stamp.write_text(digest)
 native=receipt(ROOT,out,build,snapshot,cmd,fingerprint,native_flags)
 (out/'compile.log').write_text((build/'compile.log').read_text())
 sim=[build/'simv','-no_save','+STIM='+str(out/'stimulus.txt'),'+OBS_DIR='+str(out),'+FSDB='+str(out/'waves.fsdb'),'+END_TICKS='+str(c['end_ticks']-1),'+BW_EXPECT='+str(out/'expect.cfg')]
 command(sim,build,out/'run.log');log=(out/'run.log').read_text();assert 'TB_PASS acceptance' in log and 'Fatal:' not in log and 'Error-[' not in log
 ready=packets(log,'BW_READY');assert len(ready)==1
 origin=int(ready[0]['time_ticks']);c,rows=at_measurement_start(c,rows,origin)
 result=check_trace(c,out,rows)
 assert 'BW_CFG WARNING' not in log and 'BW_CFG_WARNING' not in log
 reference_frames=frame_table(rows);reference_windows=window_table(c,rows,reference_frames)
 result['analysis_counts']=verify_analysis(c,rows,reference_frames,reference_windows,log)
 result['report_reference']=verify_reports(c,rows,reference_frames,reference_windows,log,(out/'expect.cfg').read_text())
 checks=re.findall(r'^BW_CHECK .*$',log,re.M);summary=re.findall(r'^BW_SUMMARY .*$',log,re.M)
 assert len(summary)==1 and 'scopes_done=16 scopes_expected=16' in summary[0]
 for outcome,key in [('PASS','pass'),('FAIL','fail'),('WARNING','warning')]:
  n=sum('conclusion='+outcome+' ' in x for x in checks)
  assert re.search(r'\b'+key+'='+str(n)+r'\b',summary[0]),(outcome,n,summary)
 if scene.startswith('e4_'):
  expected='PASS' if scene=='e4_boundary' else 'FAIL';actual={'e4_boundary':'152','e4_below':'151.99000000000001','e4_low':'128'}[scene]
  matching=next(x for x in packets(log,'BW_CHECK') if x['metric']=='e2e_bw')
  assert matching['conclusion']==expected and float(matching['effective_min'])==152
  target={'e4_boundary':152.0,'e4_below':151.99,'e4_low':128.0}[scene]
  assert abs(float(matching['actual'])-target)<1e-10,('E4 actual',matching,target)
 if scene=='varying':
  assert any('metric=steady_bw ' in x and 'conclusion=PASS ' in x for x in checks)
  assert any('metric=episode_cv ' in x and 'conclusion=FAIL ' in x for x in checks)
 if scene in ['size_unknown','valid_unknown','reset_unknown','no_episode','truncated','zero']:
  assert any('conclusion=WARNING ' in x and 'actual=UNAVAILABLE ' in x for x in checks)
 if scene=='e3_boundary':
  markers=packets(log,'ACCEPT_E3_ORDER');assert {x['scope'] for x in markers}=={'p0','die0','all_dmc','mixed'}
 if scene=='e3_delayed':
  assert not packets(log,'BW_PHASE'), 'original N3 vector is too short for a surviving N6 phase'
  assert all(e['e2e_valid']=='1' for e in packets(log,'BW_EPISODE'))
 if scene=='e3_delayed_fixed':
  phases=packets(log,'BW_PHASE')
  for scope in ['p0','die0_dmc','all_dmc','mixed']:
   p=next(p for p in phases if p['scope']==scope)
   assert [int(p[k]) for k in ['start_ticks','confirm_ticks','end_ticks','start_bytes','end_bytes','start_events','end_events']]==[origin+150000000,origin+160000000,origin+156000000,640,640,1,2]
 if scene=='hints':
  hits=packets(log,'BW_HINT_HIT');ends=packets(log,'BW_HINT_END')
  assert len(hits)==len(ends)==1 and hits[0]['scope']=='p1'
  assert [int(hits[0][k]) for k in ['start_ticks','trigger_ticks','duration_ticks']]==[origin+85000000,origin+87000000,2000000]
  assert [int(ends[0][k]) for k in ['end_ticks','duration_ticks']]==[origin+95000000,10000000]
  assert ends[0]['hit']=='1' and ends[0]['reason']=='RELEASED'
 if scene=='protocols':
  raw=reference_frames
  assert next(f for f in raw['p1'] if f['t']==origin+61*TICKS)['bc'] and next(f for f in raw['p1'] if f['t']==origin+61*TICKS)['events']==0
  assert next(f for f in raw['p2'] if f['t']==origin+61*TICKS)['bytes']==64
 if scene=='e5':
  observed={}
  for x in packets(log,'BW_CHECK'):observed.setdefault((x['scope_kind'],x['scope']),set()).add(x['metric'])
  assert observed=={('0','tb.top.master0.bw'):{'e2e_bw','steady_bw','ramp_time','steady_cv'},('1','memory_all'):{'steady_bw','episode_cv'}},observed
 result['performance_checks']=checks;result['summary']=summary[0]
 assert (out/'waves.fsdb').stat().st_size>0
 (out/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
 write_tables(c,rows,out,result)
 dependencies=dict(fingerprint['project_sha256'])
 dependencies.update({str(p.relative_to(ROOT)) if ROOT in p.parents else str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [out/'stimulus.txt',out/'expect.cfg']})
 manifest={'configuration':c,'input_time_basis':'offset from published measurement start','top':top,'compile':[str(x) for x in cmd],'run':[str(x) for x in sim],'source_snapshot':str(snapshot),'base_revision':native['runtime_head'],'dependency_sha256':dependencies,'runtime_evidence':native,'compiler':fingerprint['tools']['vcs_version'],'actual_observation_end_ticks':c['end_ticks'],'human_review':'PENDING'}
 (out/'commands.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS',scene,basis,result['counts'],'realFSDB',out/'waves.fsdb',flush=True)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--scene',choices=PRIMARY+SUPPLEMENTAL,default='steady');p.add_argument('--basis',choices=['ns','cycle'],default='ns');p.add_argument('--all',action='store_true');p.add_argument('--cflags',default='',help='additional native C compiler options, recorded in the build fingerprint');p.add_argument('--output-root',type=Path,help='separate new runs from frozen historical evidence');args=p.parse_args()
 output_root=args.output_root.resolve() if args.output_root else None
 if args.all:
  for s in PRIMARY:
   for b in ['ns','cycle']:one(s,b,args.cflags,output_root)
  for s in SUPPLEMENTAL:one(s,'ns',args.cflags,output_root)
 else:
  if args.scene in SUPPLEMENTAL and args.basis!='ns':p.error('supplemental exact-vector scene uses its declared NS context')
  one(args.scene,args.basis,args.cflags,output_root)
if __name__=='__main__':main()
