"""Supplement existing full COMMON builds using their actual optimized gcc argv."""
import datetime,hashlib,json,os,shlex,shutil,subprocess
from pathlib import Path

root=Path('/tmp/bw-mon-spec13-resume/common29-final-467b722-50732b4bc8365bd2')
out=root/'native-postrun-supplement'
sha=lambda data:hashlib.sha256(data).hexdigest()
def digest(path):return sha(Path(path).read_bytes())
def stat_record(path):
    p=Path(path);s=p.stat()
    return dict(path=str(p),resolved_path=str(p.resolve()),sha256=digest(p),size=s.st_size,
                device=s.st_dev,inode=s.st_ino,mtime_ns=s.st_mtime_ns,ctime_ns=s.st_ctime_ns)
receipt_bytes=(root/'launch-receipt.json').read_bytes();receipt=json.loads(receipt_bytes.decode())
start=int(datetime.datetime.strptime(receipt['launched_utc'],'%Y-%m-%dT%H:%M:%S.%fZ').replace(tzinfo=datetime.timezone.utc).timestamp()*10**9)
manifests=[]
for job in receipt['jobs']:
    paths=list((Path(job['output_root'])/'runs'/job['profile']).glob('*/manifest.json'));assert len(paths)==1
    m=json.loads(paths[0].read_text());assert m['checked_pass'] is True and m['state']=='VERIFIED',job['profile']
    manifests.append(m)
out.mkdir(exist_ok=True);groups=[];all_headers=None
for m in manifests:
    build=Path(m['compile']['cwd']);source=str(Path(m['source_snapshot'])/'rtl/bw_slot_settlement.c')
    log=Path(m['compile']['log']);lines=log.read_text().splitlines()
    matches=[(i+1,line,shlex.split(line)) for i,line in enumerate(lines) if line.startswith('gcc ') and ' -c ' in line and source in line]
    assert len(matches)==1,m['scenario']
    number,line,argv=matches[0];assert argv.count('-O')==1 and argv[-2:]==['-c',source]
    query=argv[:-2]+['-M',source]
    completed=subprocess.run(query,cwd=str(build/'csrc'),stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    assert completed.returncode==0 and not completed.stderr
    dependency_file=m['scenario']+'.full-M.d';(out/dependency_file).write_bytes(completed.stdout)
    deps=completed.stdout.decode().replace('\\\n',' ').split(':',1)[1].split()
    assert deps[0]==source and len(deps)==51
    headers=sorted(set(deps[1:]));assert len(headers)==50
    if all_headers is None:all_headers=headers
    assert all_headers==headers
    native_d=build/'csrc/bw_slot_settlement.d'
    native_deps=native_d.read_text().replace('\\\n',' ').split(':',1)[1].split()
    assert native_deps[0]==source and set(native_deps[1:])==set(receipt['sdk']['header_sha256'])
    groups.append(dict(profile=m['scenario'],original_native_argv=argv,original_cwd=str(build/'csrc'),
        actual_compile_log_line=number,actual_compile_log_line_text=line,actual_compile_log_sha256=digest(log),
        dependency_query_argv=query,dependency_query_cwd=str(build/'csrc'),dependency_query_returncode=completed.returncode,
        dependency_query_stderr=completed.stderr.decode(),dependency_file=dependency_file,dependency_sha256=sha(completed.stdout),
        header_paths=headers,header_count=50,native_dependency_sha256=digest(native_d),
        native_object_sha256=digest(build/'csrc/bw_slot_settlement.o'),simulator_sha256=digest(build/'simv')))
before={name:stat_record(name) for name in all_headers}
for name,expected in receipt['sdk']['header_sha256'].items():assert before[name]['sha256']==expected
for name,info in before.items():assert max(info['mtime_ns'],info['ctime_ns'])<start,name
compiler=stat_record(Path(shutil.which('gcc')).resolve());assert max(compiler['mtime_ns'],compiler['ctime_ns'])<start
version=subprocess.run(['gcc','--version'],stdout=subprocess.PIPE,stderr=subprocess.PIPE);assert version.returncode==0
for group in groups:
    repeated=subprocess.run(group['dependency_query_argv'],cwd=group['dependency_query_cwd'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    assert repeated.returncode==0 and not repeated.stderr and sha(repeated.stdout)==group['dependency_sha256']
assert before=={name:stat_record(name) for name in all_headers}
assert compiler==stat_record(Path(shutil.which('gcc')).resolve())
assert receipt_bytes==(root/'launch-receipt.json').read_bytes()
record=dict(kind='post-run metadata supplement; not a pre-run50-header freeze',recorded_utc=datetime.datetime.utcnow().isoformat()+'Z',
    source_head=receipt['source_head'],source_tree=receipt['source_tree'],original_launch_receipt_sha256=sha(receipt_bytes),
    original_sdk_inventory_count=2,full_observed_native_flag_inventory_count=50,
    header_sha256={name:info['sha256'] for name,info in before.items()},header_file_stability=before,
    file_stability_rechecked_after_dependency_queries=True,all_header_mtime_and_ctime_precede_campaign_start=True,
    campaign_started_utc=receipt['launched_utc'],campaign_start_epoch_ns=start,campaign_finished_utc=max(m['finished_utc'] for m in manifests),
    compiler_binary=compiler,compiler_version=version.stdout.decode(),
    relevant_current_include_environment={name:os.environ.get(name) for name in ('CPATH','C_INCLUDE_PATH','CPLUS_INCLUDE_PATH','OBJC_INCLUDE_PATH','GCC_EXEC_PREFIX','COMPILER_PATH')},
    groups=groups,native_command_count=len(groups),
    native_dot_d_scope='Original VCS .d files remain unchanged: source and2SDKheaders only; system headers use this separate full-M inventory.',
    inference='Actual recorded gcc commands include -O, so a plain gcc-M query omits stdlib-bsearch.h. All4 actual command replays identify50headers; all50current file mtime/ctime and compiler mtime/ctime predate campaign start and stayed stable across replay. This retrospective metadata supplement is not a new simulation or a pre-run50header snapshot.',
    simulation_or_native_rebuild_performed=False,vendor_or_system_header_contents_copied=False,survey_script_sha256=digest(Path(__file__)))
(out/'native-full-flags-supplement.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
(out/'survey.py').write_bytes(Path(__file__).read_bytes())
print(json.dumps(dict(profiles=len(groups),headers=50,mtime_ctime_precede_campaign=True,output=str(out/'native-full-flags-supplement.json'))))
