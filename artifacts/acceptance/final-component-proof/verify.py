#!/usr/bin/env python3
"""Verify original 427-case component evidence without VCS or old worktrees."""
import argparse,datetime,hashlib,json,re,shlex,tarfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
sha=lambda data:hashlib.sha256(data).hexdigest()

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--current-source',action='store_true')
 parser.add_argument('--current-native-headers',action='store_true',help='also check the locally installed actual-flags50 header and compiler hashes')
 parser.add_argument('--source-root',type=Path,default=HERE.parents[2])
 args=parser.parse_args()
 proof=json.loads((HERE/'verification.json').read_text());entry=proof['archive'];archive_path=HERE/entry['file']
 assert proof['cases']==proof['runtime_contracts_verified']==427
 assert proof['top_groups']==proof['cache_stamps_verified']==proof['native_build_records_verified']==168
 assert proof['source_unchanged'] and proof['compiler_diagnostics']==0
 assert archive_path.stat().st_size==entry['bytes'] and sha(archive_path.read_bytes())==entry['sha256']
 with tarfile.open(str(archive_path),'r:gz') as archive:
  members=archive.getmembers();assert len(members)==len(entry['files'])
  content={}
  for member in members:
   path=Path(member.name);assert member.isfile() and not path.is_absolute() and '..' not in path.parts
   raw=archive.extractfile(member).read();assert sha(raw)==entry['files'][member.name],member.name;content[member.name]=raw
 freeze=json.loads(content['freeze.json'].decode());state=json.loads(content['campaign/state.json'].decode())
 assert freeze['head']==state['head']==proof['source_head'] and freeze['tree']==proof['source_tree']
 assert state['cases']==state['passed_cases']==427 and state['state']=='VERIFIED' and state['source_changed']==[]
 assert content['campaign/source-before.json']==content['campaign/source-after.json']
 for name,digest in json.loads(content['campaign/source-before.json'].decode()).items():assert sha(content['source/'+name])==digest,name
 cases=json.loads(content['source/tests/cases.json'].decode());commands=json.loads(content['campaign/commands-audit.json'].decode())
 assert len(cases)==len(commands['cases'])==427
 observed=[]
 for shard in state['shards']:
  assert shard['state']=='PASSED' and shard['returncode']==0
  text=content['campaign/'+Path(shard['log']).name].decode()
  assert not re.search(r'^FAIL ',text,re.M)
  passed=re.findall(r'^PASS ([^:]+):',text,re.M);assert len(passed)==shard['cases'];observed+=passed
 assert len(observed)==len(set(observed))==427 and set(observed)=={case['name'] for case in cases}
 warnings=[]
 for case in cases:
  text=content['runtime/'+case['name']+'.log'].decode()
  if case.get('expect_error'):
   assert 'Fatal:' in text and re.search(case['expect_error'],text) and 'TB_PASS' not in text and 'expected core error did not occur' not in text,case['name']
  else:assert 'TB_PASS' in text and 'Fatal:' not in text,case['name']
  assert all(re.search(pattern,text) for pattern in case.get('expect_log',[])),case['name']
  assert all(len(re.findall(pattern,text))==count for pattern,count in case.get('expect_counts',{}).items()),case['name']
  if re.search(r'^Warning-\[',text,re.M):warnings.append(case['name'])
 assert warnings==['report_unreadable'],warnings
 root=Path(freeze['root']);rtl=[name[7:] for name in content if name.startswith('source/rtl/')]
 sources=sorted([name for name in rtl if name.endswith('.sv')],key=lambda name:(Path(name).name!='bw_mon_pkg.sv',Path(name).name))+sorted(name for name in rtl if name.endswith('.c'))
 headers=sorted(name for name in rtl if Path(name).suffix in {'.svh','.vh','.h'})
 tops={case['top'] for case in cases};assert len(tops)==len(commands['tops'])==168
 top_records={record['top']:record for record in commands['tops']}
 for top in tops:
  case=[case for case in cases if case['top']==top][-1]
  dependencies=sources+['tests/'+name for name in case.get('sources',[])]+['tests/'+top+'.sv']+headers
  digest=sha(str(root).encode()+content['source/tests/run.py']+json.dumps(case.get('defines',[])).encode()+b''.join(str(root/name).encode()+content['source/'+name] for name in dependencies))
  assert content['stamps/'+top+'.sha256'].decode()==top_records[top]['cache_digest']==digest,top
  assert not re.search(rb'(?:Warning|Error)-\[',content['compile/'+top+'.log']),top
  native=content['native/'+top+'.d'];assert sha(native)==top_records[top]['native_dependencies_sha256']
  dependencies=native.decode().replace('\\\n',' ').split(':',1)[1].split()
  assert dependencies[0]==str(root/'rtl/bw_slot_settlement.c') and set(dependencies[1:])==set(freeze['vendor_sdk_headers']),top
  assert '+vpi' in top_records[top]['compile_argv_reconstructed_from_frozen_runner']
 supplement=json.loads(content['native/postrun-supplement/native-full-flags-supplement.json'].decode())
 assert supplement['source_head']==proof['source_head'] and supplement['original_freeze_sha256']==sha(content['freeze.json'])
 assert supplement['original_plain_M_inventory_count']==len(freeze['native_header_sha256'])==49
 assert supplement['full_observed_native_flag_inventory_count']==len(supplement['header_sha256'])==50
 assert proof['native_original_plain_preprocessor_header_hashes_verified']==49 and proof['native_actual_flags_header_hashes_verified']==50
 assert supplement['simulation_or_native_rebuild_performed'] is False and supplement['vendor_or_system_header_contents_copied'] is False
 assert supplement['added_header_paths']==['/usr/include/bits/stdlib-bsearch.h']
 assert set(supplement['header_sha256'])-set(freeze['native_header_sha256'])==set(supplement['added_header_paths'])
 assert all(supplement['header_sha256'][name]==digest for name,digest in freeze['native_header_sha256'].items())
 start_ns=int(datetime.datetime.strptime(state['started_utc'],'%Y-%m-%dT%H:%M:%S.%fZ').replace(tzinfo=datetime.timezone.utc).timestamp()*10**9)
 assert supplement['campaign_start_epoch_ns']==start_ns and supplement['campaign_started_utc']==state['started_utc']
 assert supplement['all_header_mtime_and_ctime_precede_campaign_start'] and supplement['file_stability_rechecked_after_dependency_queries']
 assert set(supplement['header_file_stability'])==set(supplement['header_sha256'])
 for name,row in supplement['header_file_stability'].items():
  assert row['path']==name and row['sha256']==supplement['header_sha256'][name]
  assert row['size']>0 and max(row['mtime_ns'],row['ctime_ns'])<start_ns,name
 compiler=supplement['compiler_binary'];assert compiler['size']>0 and max(compiler['mtime_ns'],compiler['ctime_ns'])<start_ns
 groups={row['index']:row for row in supplement['groups']};assert len(groups)==2
 assert {('-DBW_MON_TEST_FAULTS' in row['original_native_argv']) for row in groups.values()}=={False,True}
 for row in groups.values():
  argv=row['original_native_argv'];assert argv[0]=='gcc' and '-O' in argv and argv[-2:]==['-c',str(root/'rtl/bw_slot_settlement.c')]
  assert row['dependency_query_argv']==argv[:-2]+['-M',argv[-1]] and row['dependency_query_cwd']==row['original_cwd']
  assert row['dependency_query_returncode']==0 and row['dependency_query_stderr']==''
  native=content['native/postrun-supplement/'+row['dependency_file']];assert sha(native)==row['dependency_sha256']
  deps=native.decode().replace('\\\n',' ').split(':',1)[1].split()
  assert deps[0]==argv[-1] and len(deps)==51 and set(deps[1:])==set(row['header_paths'])==set(supplement['header_sha256'])
  assert row['header_count']==50
 native_commands=supplement['actual_native_commands_verified'];assert supplement['native_command_count']==len(native_commands)==168
 assert {row['top'] for row in native_commands}==tops
 for row in native_commands:
  top=row['top'];group=groups[row['group_index']];assert top in group['tops']
  raw=content['compile/'+top+'.log'];assert sha(raw)==row['compile_log_sha256']
  line=raw.decode().splitlines()[row['compile_log_line']-1]
  assert line==row['compile_log_line_text'] and shlex.split(line)==group['original_native_argv']
  assert row['native_dependency_sha256']==sha(content['native/'+top+'.d'])
  assert row['native_object_sha256']==top_records[top]['native_object_sha256'] and row['simulator_sha256']==top_records[top]['binary_sha256']
 assert sorted(top for group in groups.values() for top in group['tops'])==sorted(tops)
 preservation=json.loads(content['native/postrun-supplement/original-evidence-preservation.json'].decode())
 assert preservation['original_members_byte_identical']==proof['original_actual_evidence_members_preserved']
 assert preservation['all_original_runtime_compile_cache_native_source_freeze_targeted_and_campaign_records_preserved'] and preservation['supplement_is_metadata_only']
 assert preservation['new_simulation_or_native_rebuild'] is False
 if args.current_native_headers:
  for name,row in supplement['header_file_stability'].items():
   p=Path(name);stat=p.stat();assert sha(p.read_bytes())==row['sha256'] and stat.st_size==row['size']
   assert stat.st_mtime_ns==row['mtime_ns'] and stat.st_ctime_ns==row['ctime_ns'],name
  p=Path(compiler['path']);stat=p.stat();assert sha(p.read_bytes())==compiler['sha256']
  assert stat.st_mtime_ns==compiler['mtime_ns'] and stat.st_ctime_ns==compiler['ctime_ns']
  print('PASS local actual-native-flags50 header/compiler hashes and recorded file stability')
 for name,digest in freeze['rtl_sha256'].items():assert sha(content['source/'+name])==digest,name
 if args.current_source:
  production={str(path.relative_to(args.source_root)) for path in (args.source_root/'rtl').rglob('*') if path.is_file()}
  assert production==set(freeze['rtl_sha256'])
  for name,digest in freeze['rtl_sha256'].items():assert sha((args.source_root/name).read_bytes())==digest,name
  print('PASS current production RTL/C/header equality')
 print('PASS recorded source',proof['source_head'],'427 cases /168 tops /168 native builds; actual-flags50 postrun supplement; source/cache/runtime/archive hashes')

if __name__=='__main__':main()
