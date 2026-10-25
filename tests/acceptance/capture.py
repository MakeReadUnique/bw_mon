#!/usr/bin/env python3
"""Capture a fresh real nWave client; no raster or simulation-data editing."""
import argparse,ctypes,hashlib,json,os,re,struct,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('scene');p.add_argument('--view',choices=['overview','quality','episode','phase','hints','clock','protocols'],default='overview');p.add_argument('--display',default=os.environ.get('DISPLAY',':87'));p.add_argument('--begin',type=float,default=88);p.add_argument('--end',type=float,default=112);p.add_argument('--cursor',type=float,default=102.000001);args=p.parse_args()
 out=(ROOT/'artifacts/acceptance'/args.scene).resolve();fsdb=out/'waves.fsdb';assert fsdb.exists()
 meta=json.loads((out/'commands.json').read_text());base='/'+meta['top']+'/scene';point=base+'/ports[0]/dut/mon'
 def fields(scope,names):return [scope+'/'+n for n in names]
 if args.view=='overview':
  paths=fields(base+'/ports[0]/dut',['clk','reset_n','valid','accounted_bytes'])
  paths+=fields(point,['scope_id','stats_epoch','result_seq','window_start_ticks','window_end_ticks','coverage_ticks','window_bytes','window_events','window_full','window_warmup','bytes_complete','events_complete','member_reset_coverage','bandwidth_gbps'])
  paths +=[base+'/'+g+'/bandwidth_gbps' for g in ['die0','die1','all_dmc','mixed']]
  paths+=fields(base+'/all_dmc',['window_start_ticks','window_end_ticks','window_bytes','bytes_complete'])
  paths +=[base+'/ports[%d]/dut/mon/bandwidth_gbps'%i for i in [10,11]]
  paths+=fields(point,['phase_current','phase_start_ticks','phase_confirmation_ticks'])
 elif args.view=='quality':
  paths=fields(base+'/ports[0]/dut',['reset_n','valid','accounted_bytes','accounted_known'])
  paths+=fields(point,['sampled_reset_n','sampled_valid','sampled_size_known','sampled_size_bytes','stats_epoch','total_bytes','window_start_ticks','window_end_ticks','window_bytes','window_full','bytes_complete','events_complete','member_reset_coverage'])
  paths+=fields(base+'/die0',['stats_epoch','window_warmup'])+fields(base+'/all_dmc',['stats_epoch','window_bytes','bytes_complete','events_complete','member_reset_coverage','bandwidth_gbps'])
  paths+=fields(point,['episode_result_bytes_complete','episode_result_e2e_valid','episode_last_steady_selection_valid','episode_last_steady_bandwidth_valid'])
 elif args.view=='episode':
  paths=fields(point,['scope_id','episode_id','episode_active','episode_first_ticks','episode_bytes','episode_result_episode_id','episode_result_status','episode_result_first_ticks','episode_result_last_ticks','episode_result_tail_ticks','episode_result_confirmation_ticks','episode_result_byte_count','episode_result_event_count','episode_result_duration_ticks','episode_result_tail_known','episode_result_bytes_complete','episode_result_e2e_valid','episode_result_e2e_gbps'])
  paths+=fields(point,['episode_last_steady_selection_valid','episode_last_steady_start_ticks','episode_last_steady_end_ticks','episode_last_steady_bandwidth_valid','episode_last_steady_bandwidth_gbps','episode_last_steady_variation_mean_gbps','episode_last_steady_variation_stddev_gbps','episode_variation_cv_valid','episode_variation_cv_pct'])
 elif args.view=='phase':
  paths=fields(point,['bandwidth_gbps','window_full','bytes_complete','phase_current','phase_candidate','phase_candidate_count','phase_candidate_ticks','phase_start_ticks','phase_confirmation_ticks','phase_evidence_count','phase_evidence_span','phase_fit_mean','phase_fit_delta','phase_fit_rms','phase_result_phase_id','phase_result_start_ticks','phase_result_end_ticks','phase_duration_ticks','phase_duration_valid','phase_bandwidth_gbps','phase_variation_sample_count','phase_variation_mean_gbps','phase_variation_stddev_gbps','episode_last_steady_selection_valid','episode_last_steady_start_ticks','episode_last_steady_end_ticks','episode_last_steady_bandwidth_gbps','episode_variation_cv_valid','episode_variation_cv_pct'])
 elif args.view=='clock':
  paths=fields(base+'/ports[0]/dut',['clk','valid'])+fields(point,['result_seq','accepted_record_seq','window_start_ticks','window_end_ticks','coverage_ticks','window_start_cycle','window_end_cycle','coverage_cycles','window_bytes','window_events','bandwidth_gbps','bytes_per_cycle','window_full','bytes_complete'])
  paths+=fields(base+'/all_dmc',['result_seq','window_start_ticks','window_end_ticks','coverage_ticks','coverage_cycles','window_bytes','bandwidth_gbps','bytes_per_cycle','window_full','bytes_complete'])
 elif args.view=='hints':
  pp=base+'/ports[1]/dut/mon'
  paths=fields(base+'/ports[1]/dut',['clk','valid','ready'])+fields(pp,['backpressure_supported','backpressure_enabled','backpressure_trusted','backpressure_active','backpressure_hit','backpressure_start_ticks','backpressure_trigger_ticks','backpressure_end_ticks','backpressure_duration_ticks','backpressure_hit_count','backpressure_interval_count','backpressure_end_reason','result_seq','accepted_record_seq','total_bytes','window_start_ticks','window_end_ticks','bandwidth_gbps'])
 else:
  pp=base+'/ports[1]/dut/mon';cp=base+'/ports[2]/dut/mon'
  paths=fields(base+'/ports[1]/dut',['valid','ready'])+fields(pp,['sampled_valid','sampled_ready','total_events','window_events','bytes_complete','events_complete','backpressure_hit_count','backpressure_duration_ticks'])
  paths+=fields(base+'/ports[2]/dut',['valid','flitv','lcrdv'])+fields(cp,['credit_balance','credit_trusted','credit_anomaly','total_events','window_events','bandwidth_gbps'])+fields(base+'/all_dmc',['window_bytes','bytes_complete','events_complete'])
 png=out/(args.view+'.png');ready=out/(args.view+'.ready');sav=out/(args.view+'.sav')
 for f in [png,ready]:
  if f.exists():f.unlink()
 env=dict(os.environ,DISPLAY=args.display)
 work=Path(tempfile.mkdtemp(prefix='verdi-',dir=str(ROOT/'.build/acceptance')))
 tcl=out/('capture-'+args.view+'.tcl');raw_sav=work/'before.sav';layout_sav=work/'layout.sav'
 code='set w [lindex [wvGetAllWindows] 0]\nwvSetDefaultValue -win $w -analogFormat Auto -analogPrecision 12\nwvAddSignal -win $w -clear '+' '.join('{'+s+'}' for s in paths)+'\n'
 for s in paths:
  if s.endswith(('_gbps','_pct','bytes_per_cycle','phase_fit_mean','phase_fit_delta','phase_fit_rms')):code+='wvSelectSignal -win $w {'+s+'}\nwvBusWaveform -win $w -digital\n'
 code+='wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on\n'
 code+='wvSetRadix -win $w -Unsigned -format Dec {'+base+'/ports[0]/dut/accounted_bytes}\n'
 code+='wvSetWindowTimeUnit -win $w 1 ns\nwvZoom -win $w %s %s\nwvSetCursor -win $w %s\n'%(args.begin,args.end,args.cursor)
 code+='wvSaveSignal -win $w {'+str(raw_sav)+'}\n'
 code+='set fd [open {'+str(raw_sav)+'} r]\nset value [read $fd]\nclose $fd\n'
 code+='regsub {viewPort[^\\n]*} $value {viewPort 10 10 1500 850 760 180} value\n'
 code+='regsub {top [0-9]+} $value {top 0} value\n'
 code+='set fd [open {'+str(layout_sav)+'} w]\nputs $fd $value\nclose $fd\nwvRestoreSignal -win $w -appendSignals off {'+str(layout_sav)+'}\n'
 for index,s in enumerate(paths,1):
  leaf=s.rsplit('/',1)[1]
  if leaf not in ['scope_id','phase_current','phase_candidate','backpressure_end_reason','episode_result_status'] and not s.endswith(('_gbps','_pct','bytes_per_cycle','phase_fit_mean','phase_fit_delta','phase_fit_rms')):
   code+='wvSetRadix -win $w -Unsigned -format Dec {(G1 '+str(index)+')}\n'
 code+='set fd [open {'+str(ready)+'} w]\nputs $fd $w\nclose $fd\nafter 3000\nupdate\n'
 code+='wvSaveSignal -win $w {'+str(sav)+'}\nwvCapture -win $w -file {'+str(png)+'}\nwvExit\n'
 tcl.write_text(code)
 command=['verdi','-nWave','-ssf',str(fsdb),'-play',str(tcl)]
 with (out/('capture-'+args.view+'.log')).open('w') as f:
  proc=subprocess.Popen(command,cwd=str(work),env=env,stdout=f,stderr=subprocess.STDOUT)
  deadline=time.monotonic()+45
  while not ready.exists() and proc.poll() is None and time.monotonic()<deadline:time.sleep(.1)
  assert ready.exists(),'Verdi did not reach capture handshake; see capture.log'
  tree=subprocess.check_output(['xwininfo','-root','-tree'],env=env,universal_newlines=True)
  candidates=[line for line in tree.splitlines() if 'nwave' in line.lower() and '"' in line]
  assert candidates,tree
  xid=int(re.search(r'0x[0-9a-f]+',candidates[0]).group(),16)
  subprocess.check_call(['xprop','-id',hex(xid),'-remove','WM_NORMAL_HINTS'],env=env,stdout=f,stderr=f)
  x=ctypes.CDLL('libX11.so.6');x.XOpenDisplay.argtypes=[ctypes.c_char_p];x.XOpenDisplay.restype=ctypes.c_void_p
  x.XMoveResizeWindow.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.c_uint,ctypes.c_uint]
  x.XSync.argtypes=[ctypes.c_void_p,ctypes.c_int];x.XCloseDisplay.argtypes=[ctypes.c_void_p]
  d=x.XOpenDisplay(args.display.encode());assert d;x.XMoveResizeWindow(d,xid,10,10,1500,850);x.XSync(d,0);x.XCloseDisplay(d)
  proc.wait(timeout=60)
 assert proc.returncode==0 and png.exists() and png.stat().st_size>0,'fresh capture failed'
 with png.open('rb') as f:
  assert f.read(8)==b'\x89PNG\r\n\x1a\n';size=struct.unpack('>II',f.read(16)[8:16])
 assert size==(1500,850),size
 # Only view-file references are made portable. Image and FSDB stay untouched.
 sav.write_text(sav.read_text().replace(str(fsdb),'waves.fsdb'))
 (out/('signals-'+args.view+'.json')).write_text(json.dumps({'public_paths':paths},indent=2)+'\n')
 (out/('capture-'+args.view+'-manifest.json')).write_text(json.dumps({'command':command,'cwd':str(work),'display':args.display,'fresh':True,'pixels':list(size),'fsdb_sha256':hashlib.sha256(fsdb.read_bytes()).hexdigest(),'png_sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'agent_visual_review':'PENDING','human_review':'PENDING'},indent=2)+'\n')
 print('Fresh actual Verdi capture',png,size)
if __name__=='__main__':main()
