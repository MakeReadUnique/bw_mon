#!/usr/bin/env python3
"""Capture a fresh real nWave client; no raster or simulation-data editing."""
import argparse,ctypes,hashlib,json,os,re,struct,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('scene');p.add_argument('--display',default=os.environ.get('DISPLAY',':87'));p.add_argument('--begin',type=float,default=88);p.add_argument('--end',type=float,default=112);p.add_argument('--cursor',type=float,default=102.000001);args=p.parse_args()
 out=(ROOT/'artifacts/acceptance'/args.scene).resolve();fsdb=out/'waves.fsdb';assert fsdb.exists()
 basis='cycle' if args.scene.endswith('_cycle') else 'ns';base='/tb_acceptance_'+basis+'/scene';point=base+'/ports[0]/dut/mon'
 paths=[base+'/ports[0]/dut/'+x for x in ['clk','reset_n','valid','accounted_bytes']]
 paths +=[point+'/'+x for x in ['scope_id','stats_epoch','result_seq','window_start_ticks','window_end_ticks','window_bytes','window_events','window_full','window_warmup','bytes_complete','member_reset_coverage','bandwidth_gbps']]
 paths +=[base+'/'+g+'/bandwidth_gbps' for g in ['die0','die1','all_dmc','mixed']]
 paths +=[base+'/ports[%d]/dut/mon/bandwidth_gbps'%i for i in [10,11]]
 paths +=[point+'/'+x for x in ['phase_current','phase_start_ticks','phase_confirmation_ticks']]
 png=out/'overview.png';ready=out/'capture.ready';sav=out/'overview.sav'
 for f in [png,ready]:
  if f.exists():f.unlink()
 env=dict(os.environ,DISPLAY=args.display)
 work=Path(tempfile.mkdtemp(prefix='verdi-',dir=str(ROOT/'.build/acceptance')))
 tcl=out/'capture.tcl';raw_sav=work/'before.sav';layout_sav=work/'layout.sav'
 code='set w [lindex [wvGetAllWindows] 0]\nwvSetDefaultValue -win $w -analogFormat Auto -analogPrecision 12\nwvAddSignal -win $w -clear '+' '.join('{'+s+'}' for s in paths)+'\n'
 for s in paths:
  if s.endswith('bandwidth_gbps'):code+='wvSelectSignal -win $w {'+s+'}\nwvBusWaveform -win $w -digital\n'
 code+='wvSetPreference -win $w -hierName on -leftalign on -partial_hier off -hier_signal_name on\n'
 code+='wvSetRadix -win $w -Unsigned -format Dec {'+base+'/ports[0]/dut/accounted_bytes}\n'
 code+='wvSetWindowTimeUnit -win $w 1 ns\nwvZoom -win $w %s %s\nwvSetCursor -win $w %s\n'%(args.begin,args.end,args.cursor)
 code+='wvSaveSignal -win $w {'+str(raw_sav)+'}\n'
 code+='set fd [open {'+str(raw_sav)+'} r]\nset value [read $fd]\nclose $fd\n'
 code+='regsub {viewPort[^\\n]*} $value {viewPort 10 10 1500 850 660 180} value\n'
 code+='regsub {top [0-9]+} $value {top 0} value\n'
 code+='set fd [open {'+str(layout_sav)+'} w]\nputs $fd $value\nclose $fd\nwvRestoreSignal -win $w -appendSignals off {'+str(layout_sav)+'}\n'
 code+='wvSetRadix -win $w -Unsigned -format Dec {(G1 4)}\n'
 code+='set fd [open {'+str(ready)+'} w]\nputs $fd $w\nclose $fd\nafter 3000\nupdate\n'
 code+='wvSaveSignal -win $w {'+str(sav)+'}\nwvCapture -win $w -file {'+str(png)+'}\nwvExit\n'
 tcl.write_text(code)
 command=['verdi','-nWave','-ssf',str(fsdb),'-play',str(tcl)]
 with (out/'capture.log').open('w') as f:
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
 (out/'signals.json').write_text(json.dumps({'public_paths':paths},indent=2)+'\n')
 (out/'capture-manifest.json').write_text(json.dumps({'command':command,'cwd':str(work),'display':args.display,'fresh':True,'pixels':list(size),'fsdb_sha256':hashlib.sha256(fsdb.read_bytes()).hexdigest(),'png_sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'agent_visual_review':'PENDING','human_review':'PENDING'},indent=2)+'\n')
 print('Fresh actual Verdi capture',png,size)
if __name__=='__main__':main()
