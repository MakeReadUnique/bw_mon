#!/usr/bin/env python3
"""Verify original 427-case component evidence without VCS or old worktrees."""
import argparse,hashlib,json,re,tarfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
sha=lambda data:hashlib.sha256(data).hexdigest()

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--current-source',action='store_true')
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
 for name,digest in freeze['rtl_sha256'].items():assert sha(content['source/'+name])==digest,name
 if args.current_source:
  production={str(path.relative_to(args.source_root)) for path in (args.source_root/'rtl').rglob('*') if path.is_file()}
  assert production==set(freeze['rtl_sha256'])
  for name,digest in freeze['rtl_sha256'].items():assert sha((args.source_root/name).read_bytes())==digest,name
  print('PASS current production RTL/C/header equality')
 print('PASS recorded source',proof['source_head'],'427 cases /168 tops /168 native builds; source/cache/runtime/archive hashes')

if __name__=='__main__':main()
