"""Validate the explicitly frozen runtime and its actual native build evidence."""
import hashlib,json,subprocess,sys
from pathlib import Path

RUNTIME_HEAD='8e81839423ab7db335365a5e577e25b2ebe5dcb0'
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def runtime_evidence(root,out):
 freeze=json.loads((out/'runtime-source.json').read_text())
 assert freeze['head']==RUNTIME_HEAD,('unexpected runtime freeze',freeze['head'])
 expected=freeze['rtl_sha256']
 production={str(p.relative_to(root)) for p in (root/'rtl').rglob('*') if p.suffix in ['.sv','.svh','.vh','.c','.h']}
 assert len(expected)==18 and set(expected)==production,('incomplete runtime freeze',production-set(expected),set(expected)-production)
 for name,digest in expected.items():assert sha(root/name)==digest,('runtime source changed',name)
 native=freeze['native_header_dependencies']
 assert {Path(name).name for name in native['vendor_headers']}=={'svdpi.h','vpi_user.h'}
 for name,digest in native['header_sha256'].items():assert sha(name)==digest,('native header changed',name)
 proof=out/'current-component-proof'
 current=json.loads((proof/'verification.json').read_text())
 assert current['source_head']==RUNTIME_HEAD and current['cases']==current['runtime_contracts_verified']==424
 result=subprocess.run([sys.executable,str(proof/'verify.py'),'--current-source'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,universal_newlines=True)
 assert result.returncode==0,('current component proof',result.stdout)
 return freeze

def scene_runtime_evidence(root,out,folder,manifest,freeze):
 for name,digest in freeze['rtl_sha256'].items():
  assert manifest['dependency_sha256'].get(name)==digest,('scene consumed a different runtime',folder.name,name)
 native=manifest['runtime_evidence']
 assert native['runtime_head']==RUNTIME_HEAD
 assert native['freeze_sha256']==sha(out/'runtime-source.json')
 assert native['source_snapshot_sha256']==freeze['rtl_sha256'],('compiled snapshot changed',folder.name)
 dependency_file=folder/'native-dependencies.d'
 assert sha(dependency_file)==native['native_dependency_makefile_sha256']
 dependencies=dependency_file.read_text().replace('\\\n',' ').split(':',1)[1].split()
 assert len(dependencies)==3 and dependencies[0].endswith('/rtl/bw_slot_settlement.c'),('unexpected native dependencies',folder.name,dependencies)
 sdk=freeze['native_header_dependencies']['vendor_headers']
 assert set(dependencies[1:])==set(sdk)
 assert native['native_dependencies_sha256']=={name:freeze['native_header_dependencies']['header_sha256'][name] for name in sdk}
 command=manifest['compile']
 assert '+vpi' in command and any(x in command for x in ['-debug_access','-debug_access+all'])
 assert '-CFLAGS' in command and '-I'+str(Path(sdk[0]).parent) in command
 assert any(name.endswith('/rtl/bw_slot_settlement.c') for name in command)
 assert len(manifest['base_revision'])==40,('missing actual checkout revision',folder.name)
