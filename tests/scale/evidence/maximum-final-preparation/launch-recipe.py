#!/usr/bin/env python3
"""One explicitly admitted immutable MAX profile; never auto-admits another."""
import argparse,datetime,hashlib,json,os,pathlib,re,shlex,shutil,subprocess,sys
BASE=pathlib.Path('/tmp/bw-mon-spec13-resume/max30-final-complete-campaign')
SOURCE=pathlib.Path('/tmp/bw-mon-spec13-resume/max30-final-frozen-31ce03c')
PLAN=pathlib.Path('/tmp/bw-mon-spec13/nominal20-newsource-revalidation-plan.json')
NOMINAL=('max-ns','max-cycle','max-ns-short-unknown','max-cycle-short-reset')
PROFILES=NOMINAL+('max-tracer-ns','max-tracer-cycle','max-tracer-unknown','max-tracer-reset')
def sha(p):
 h=hashlib.sha256()
 with pathlib.Path(p).open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''): h.update(block)
 return h.hexdigest()
def capture(argv):return subprocess.check_output(argv,cwd=str(SOURCE),universal_newlines=True,stderr=subprocess.STDOUT).strip()
def write(path,obj):
 path.parent.mkdir(parents=True,exist_ok=True)
 tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n');tmp.replace(path)
def prepare(profile):
 head=capture(['git','rev-parse','HEAD']);status=capture(['git','status','--short'])
 if head!='31ce03c16af62911985ee9191da51c7534396ebf' or status:raise RuntimeError('frozen source changed')
 sys.path.insert(0,str(SOURCE/'tests/scale'))
 from maximum import build_scenario
 scenario=build_scenario(profile)
 counts=dict(raw_receipts_checked=scenario.clock.edges*(scenario.points+len(scenario.groups)),new_window_publications_checked=sum(scenario.window_count(k,i) for k,i in scenario.scopes()),final_scope_rows=scenario.points+len(scenario.groups))
 selected=next((p for p in json.loads(PLAN.read_text())['profiles'] if p['profile']==profile),None)
 if selected:
  for key,value in counts.items():
   if selected['independent_expected_counts'][key]!=value:raise RuntimeError('fixed independent count changed:'+key)
  if scenario.topology['graph_sha256']!=selected['input_target']['topology']['graph_sha256']:raise RuntimeError('fixed graph changed')
  if (scenario.width,scenario.stride,scenario.end,scenario.clock.edges)!=(selected['input_target']['W'],selected['input_target']['S'],selected['input_target']['end_ticks'],selected['input_target']['actual_input_edges_per_scope']):raise RuntimeError('fixed target changed')
 else:selected=dict(input_target=scenario.manifest(),independent_expected_counts=counts)
 production={str(p.relative_to(SOURCE)):sha(p) for p in sorted((SOURCE/'rtl').iterdir()) if p.is_file()}
 canonical=json.loads(pathlib.Path('/tmp/bw-mon-spec13-resume/review-fix-evidence/production-milestone.json').read_text())['production_sha256']
 if production!=canonical:raise RuntimeError('runtime18 freeze mismatch')
 inventory={str(p.relative_to(SOURCE)):sha(p) for p in sorted((SOURCE/'rtl').rglob('*')) if p.is_file()}
 inventory.update({str(p.relative_to(SOURCE)):sha(p) for p in sorted((SOURCE/'tests/scale').glob('*.py'))})
 inventory['tests/scale/tb_scale_tracer.sv']=sha(SOURCE/'tests/scale/tb_scale_tracer.sv')
 sdk=pathlib.Path(shutil.which('vcs')).resolve().parents[1]/'include'
 dep_command=['gcc','-M','-w','-pipe','-fPIC','-O','-I'+str(sdk),str(SOURCE/'rtl/bw_slot_settlement.c')]
 deps=capture(dep_command)
 headers=shlex.split(deps.replace('\\\n',' ').split(':',1)[1]);header_hashes={p:sha(p) for p in headers if pathlib.Path(p).is_file() and pathlib.Path(p).resolve()!=(SOURCE/'rtl/bw_slot_settlement.c').resolve()}
 # Retain exact installed native link inputs used by this fixed VCS release.
 old_log=pathlib.Path('/tmp/bw-mon-spec13/max-topology-30-current/builds/eab232250f3232f7dafb85ef35d8fd28f86e70813b6399845eb2b15c99918223/compile-attempt-1/compile.log').read_text()
 link_line=next(l for l in old_log.splitlines() if l.startswith('g++ '))
 tokens=shlex.split(link_line);search=[pathlib.Path(t[2:]) for t in tokens if t.startswith('-L')]+[pathlib.Path('/usr/lib64'),pathlib.Path('/lib64')]
 link_inputs={}
 for token in tokens:
  if token.startswith('-l') and len(token)>2:
   candidates=[d/('lib'+token[2:]+s) for d in search for s in ('.so','.a')]
   found=next((p for p in candidates if p.is_file()),None)
   if found is not None:link_inputs[str(found)]=sha(found)
  elif token.startswith('/') and pathlib.Path(token).is_file() and token.endswith(('.a','.o','.so','.so.1')):link_inputs[token]=sha(token)
 flags=['-full64','-sverilog','-timescale=1ns/1fs','+vpi','-debug_access','-CFLAGS','-I'+str(sdk),'+incdir+<immutable consumed RTL>','-assert','svaext','-top','tb_bw_scale','-o','<isolated build>/simv']
 identity=dict(source_sha256=inventory,native_header_sha256=header_hashes,installed_native_link_input_sha256=link_inputs,compile_options=flags,profile_input=selected['input_target'],vcs=capture(['vcs','-ID']),gcc=capture(['gcc','--version']),gxx=capture(['g++','--version']))
 digest=hashlib.sha256(json.dumps(identity,sort_keys=True).encode()).hexdigest()
 root=BASE/(profile+'-'+digest[:20])
 receipt=dict(launcher_sha256=sha(pathlib.Path(__file__)),profile=profile,source_root=str(SOURCE),source_head=head,source_tree=capture(['git','rev-parse','HEAD^{tree}']),production_runtime='56127495f597d215003000356ac3b5387cc809a1',production_sha256=production,complete_build_identity=digest,identity=identity,native_dependency_command=dep_command,native_dependencies=deps,output_root=str(root),expected_counts=selected['independent_expected_counts'],state='PREPARED_NOT_LAUNCHED')
 return root,receipt
p=argparse.ArgumentParser();p.add_argument('profile',choices=PROFILES);p.add_argument('--launch',action='store_true');p.add_argument('--nominal-admitted',action='store_true');args=p.parse_args()
if args.launch and args.profile in NOMINAL and not args.nominal_admitted:raise SystemExit('full MAX requires explicit root29closed/resource admission; no launch')
root,receipt=prepare(args.profile)
path=BASE/(args.profile+'-launch.json')
if path.exists():
 previous=json.loads(path.read_text())
 if previous.get('runner_pid'):raise RuntimeError('profile already launched; inspect existing receipt, never duplicate')
if args.launch:
 if root.exists():raise RuntimeError('fresh output root already exists')
 root.mkdir(parents=True)
 argv=[sys.executable,'-B',str(SOURCE/'tests/scale/maximum.py'),args.profile,'--force-compile','--output-root',str(root)]
 with (root/'runner.log').open('w') as log:
  proc=subprocess.Popen(argv,cwd=str(SOURCE),stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 receipt.update(argv=argv,runner_pid=proc.pid,launched_utc=datetime.datetime.utcnow().isoformat()+'Z',state='LAUNCHED_NOT_PASSED',host_before=dict(memory=capture(['free','-m']),cpus=capture(['getconf','_NPROCESSORS_ONLN']),uptime=capture(['uptime'])),admission=('root permits serial public tracers during new common qualification; tracer is not nominal acceptance' if args.profile not in NOMINAL else 'root must explicitly admit nominal profile after final-source29closes; complete resource receipt retained'))
write(path,receipt)
print(json.dumps(dict(profile=args.profile,receipt=str(path),state=receipt['state'],complete_build_identity=receipt['complete_build_identity'],runner_pid=receipt.get('runner_pid'),output_root=str(root))))
