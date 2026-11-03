#!/usr/bin/env python3
"""Run the tiny public integration slice and its intentional reference-error red."""
import datetime,json,re,shutil,subprocess,sys
from pathlib import Path
from run import REPO,HERE,execute,save,sha

def main():
    output=REPO/'.build/scale-tracer'/datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S')
    output.mkdir(parents=True)
    sources=sorted((REPO/'rtl').glob('*.sv'),key=lambda p:(p.name!='bw_mon_pkg.sv',p.name))
    sources+=sorted((REPO/'rtl').glob('*.c'))
    files=sources+[HERE/'tb_scale_tracer.sv']
    dependencies=files+sorted(p for p in (REPO/'rtl').rglob('*') if p.suffix in {'.svh','.vh','.h'})+[HERE/'tracer.py',HERE/'run.py']
    snapshot=output/'source'
    for source in dependencies:
        target=snapshot/source.relative_to(REPO);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(str(source),str(target))
    manifest=dict(kind='small_vertical_tracer',source_snapshot=str(snapshot),source_sha256={str(p.relative_to(REPO)):sha(p) for p in dependencies},state='PREPARED')
    path=output/'manifest.json'
    vcs_include=Path(shutil.which('vcs')).resolve().parents[1]/'include'
    cmd=['vcs','-full64','-error=AOUP','-sverilog','-timescale=1ns/1fs','+vpi','-debug_access','-CFLAGS','-I'+str(vcs_include),'+incdir+'+str(snapshot/'rtl'),'-assert','svaext','-top','tb_scale_tracer','-o',str(output/'simv')]+[str(snapshot/p.relative_to(REPO)) for p in files]
    result=execute(cmd,output,output/'compile.log',output/'compile.time-v.txt',path,manifest,'compile')
    if result['returncode'] or re.search(r'(?:Warning|Error)-\[',(output/'compile.log').read_text()):return 1
    passed=True
    for name,args in [('red',['+INJECT_CHECKER_ERROR']),('green',[])]:
        result=execute([str(output/'simv'),'-no_save']+args,output,output/(name+'.log'),output/(name+'.time-v.txt'),path,manifest,name)
        text=(output/(name+'.log')).read_text()
        if name=='red':good='Fatal:' in text and 'TRACER_WINDOW_MISMATCH' in text and 'SCALE_TRACER_PASS' not in text
        else:
            marker=re.search(r'SCALE_TRACER_PASS scopes=5 windows=120 records=2400 tick=(\d+) start_ticks=(\d+)',text)
            good=result['returncode']==0 and 'Fatal:' not in text and marker is not None and int(marker[2])>0 and int(marker[1])-int(marker[2])==240000000
        manifest[name]['checked_pass']=good;passed=passed and good
    manifest['state']='VERIFIED' if passed else 'FAILED';save(path,manifest)
    print(('PASS' if passed else 'FAIL')+' vertical tracer/sensitivity '+str(path))
    return not passed
if __name__=='__main__':sys.exit(main())
