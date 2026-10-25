#!/usr/bin/env python3
"""Run public12-point acceptance scenes with independent input-table checks."""
import argparse,csv,hashlib,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TICKS=1000000

def run_command(command,cwd,log):
 with Path(log).open('w') as f:
  result=subprocess.run([str(x) for x in command],cwd=str(cwd),stdout=f,stderr=subprocess.STDOUT)
 if result.returncode:raise RuntimeError('command failed: '+str(log))

def steady_stimulus(path):
 rows=[]
 for edge in range(1,320):
  t=edge*500000;active=4095 if t<120*TICKS else 0
  rows.append([t,1,active,4095,active,4095,0,0,0,1,1]+[64]*12)
 path.write_text(''.join(' '.join(str(x) for x in row)+'\n' for row in rows))
 return rows

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--scene',default='steady');p.add_argument('--basis',choices=['ns','cycle'],default='ns');args=p.parse_args()
 build=ROOT/'.build'/'acceptance'/args.basis;build.mkdir(parents=True,exist_ok=True)
 out=ROOT/'artifacts'/'acceptance'/(args.scene+'_'+args.basis);out.mkdir(parents=True,exist_ok=True)
 rows=steady_stimulus(out/'stimulus.txt')
 sources=sorted((ROOT/'rtl').glob('*.sv'),key=lambda x:(x.name!='bw_mon_pkg.sv',x.name))
 top='tb_acceptance_'+args.basis
 cmd=['vcs','-full64','-sverilog','-debug_access+all','-kdb','+incdir+'+str(ROOT/'rtl'),'-assert','svaext','-top',top,'-o',build/'simv']+sources+[ROOT/'tests/acceptance/scene.sv']
 run_command(cmd,build,out/'compile.log')
 sim=[build/'simv','-no_save','+STIM='+str(out/'stimulus.txt'),'+OBS_DIR='+str(out),'+FSDB='+str(out/'waves.fsdb'),'+END_TICKS='+str(160*TICKS)]
 run_command(sim,build,out/'run.log')
 log=(out/'run.log').read_text();assert 'TB_PASS acceptance' in log and 'Fatal:' not in log
 expected={'p'+str(i):128 for i in range(12)};expected.update(die0=512,die1=512,all_dmc=1024,mixed=768)
 table=[]
 for name,rate in expected.items():
  data=list(csv.reader((out/(name+'.csv')).open()));windows=[r for r in data if r[0]=='W' and int(r[5])>=102*TICKS and int(r[5])<=103*TICKS]
  assert windows,'missing public window '+name
  r=windows[0];actual=float(r[12]);assert abs(actual-rate)<1e-10,(name,actual,rate)
  assert r[14:20]==['1','0','1','1','1','0'],(name,r)
  if args.basis=='cycle':assert abs(float(r[13])-rate/2)<1e-10
  table.append({'scope':name,'start_ticks':int(r[4]),'end_ticks':int(r[5]),'expected_gbps':rate,'actual_gbps':actual,'difference':actual-rate})
 assert (out/'waves.fsdb').stat().st_size>0
 (out/'comparison.json').write_text(json.dumps({'status':'PASS','human_review':'PENDING','checks':table},indent=2)+'\n')
 (out/'commands.json').write_text(json.dumps({'compile':[str(x) for x in cmd],'run':[str(x) for x in sim],'source_sha256':{str(x.relative_to(ROOT)):hashlib.sha256(x.read_bytes()).hexdigest() for x in sources+[ROOT/'tests/acceptance/scene.sv']}},indent=2)+'\n')
 print('PASS',args.scene,args.basis,len(table),'public scopes; realFSDB',out/'waves.fsdb')
if __name__=='__main__':main()
