#!/usr/bin/env python3
"""Prepare portable public views; optionally capture selected original FSDBs."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CAPTURE=ROOT/'tests/acceptance/capture.py'
def choices(name):
 scene,basis=name.rsplit('_',1);cursor=102.000001 if basis=='ns' else 102.500001;begin,end=88,112;extra=[]
 if scene=='steady' and basis=='cycle':extra=[('clock',88,112,102.500001)]
 if scene=='start_stop':begin,end,cursor=10,80,61.000001 if basis=='ns' else 61.500001
 if scene in ['varying','e5']:begin,end,cursor=20,155,153.000001;extra=[('phase',20,155,153.000001),('episode',125,155,153.000001)]
 if scene in ['point_reset','child_reset','upper_reset','size_unknown','valid_unknown','reset_unknown']:
  begin,end,cursor=100,118,105.000001 if basis=='ns' else 105.500001;extra=[('quality',100,118,cursor),('episode',100,134,133.000001)]
 if scene in ['clock_stop','frequency']:
  begin,end,cursor=72,116,101.000001 if scene=='clock_stop' else 103.500001
  extra=[('clock',begin,end,cursor)]
 if scene=='hints':begin,end,cursor=78,103,90.000001;extra=[('hints',78,103,90.000001),('clock',72,116,101.000001)]
 if scene=='protocols':begin,end,cursor=59,66,61.000001;extra=[('protocols',59,66,61.000001)]
 if scene=='e2':begin,end,cursor=7,24,11.000001 if basis=='ns' else 11.500001
 if scene=='isolated':begin,end,cursor=15,34,30.000001 if basis=='ns' else 30.500001
 if scene in ['zero','no_episode']:begin,end,cursor=18,56,53.000001;extra=[('episode',18,56,53.000001)]
 if scene=='truncated':begin,end,cursor=100,110.000001,110.000001;extra=[('episode',100,110.000001,110.000001)]
 if scene=='e3_boundary':begin,end,cursor=76,136,132.000001;extra=[('episode',76,136,132.000001)]
 if scene=='e3_delayed':begin,end,cursor=90,196.000001,196.000001;extra=[('phase',90,160,150.000001),('episode',110,196.000001,196.000001)]
 if scene.startswith('e4_'):begin,end,cursor=45,118,114.000001;extra=[('episode',45,118,114.000001)]
 return [('overview',begin,end,cursor)]+extra
SELECTED={'steady_ns':['overview'],'steady_cycle':['overview','clock'],'protocols_ns':['protocols'],'start_stop_ns':['overview'],'start_stop_cycle':['overview'],'varying_ns':['phase','episode'],'varying_cycle':['phase'],'point_reset_ns':['quality'],'child_reset_ns':['quality'],'upper_reset_ns':['quality'],'size_unknown_ns':['quality','episode'],'valid_unknown_ns':['quality'],'reset_unknown_ns':['quality'],'clock_stop_ns':['clock'],'clock_stop_cycle':['clock'],'frequency_ns':['clock'],'frequency_cycle':['clock'],'hints_cycle':['hints'],'zero_ns':['episode'],'no_episode_ns':['episode'],'truncated_cycle':['episode'],'isolated_ns':['overview'],'e2_ns':['overview'],'e3_boundary_ns':['episode'],'e3_delayed_ns':['phase','episode'],'e4_boundary_ns':['episode'],'e4_below_ns':['episode'],'e4_low_ns':['episode'],'e5_ns':['episode']}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',action='store_true');p.add_argument('--display',default=':87');args=p.parse_args()
 for directory in sorted((ROOT/'artifacts/acceptance').iterdir()):
  if not (directory/'commands.json').exists():continue
  for view,begin,end,cursor in choices(directory.name):
   cmd=[sys.executable,str(CAPTURE),directory.name,'--view',view,'--begin',str(begin),'--end',str(end),'--cursor',str(cursor),'--display',args.display]
   subprocess.check_call(cmd+['--prepare'],cwd=str(ROOT))
   if args.capture and view in SELECTED.get(directory.name,[]):subprocess.check_call(cmd,cwd=str(ROOT))
if __name__=='__main__':main()
