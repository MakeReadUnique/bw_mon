#!/usr/bin/env python3
"""Verify the frozen repaired-source campaign without VCS or former /tmp paths."""
import argparse,gzip,hashlib,json,re,shlex,subprocess,sys,tempfile
from pathlib import Path

repo=Path(__file__).resolve().parents[3]
sha=lambda data:hashlib.sha256(data).hexdigest()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('campaign',type=Path)
parser.add_argument('--current-source',action='store_true',help='also require every production RTL/C/header to match this checkout')
args=parser.parse_args()
base=args.campaign.resolve()
indices=list(base.glob('source-*/source-index.json'));assert len(indices)==1
snapshot_path=indices[0]
snapshot=json.loads(snapshot_path.read_text())
receipt=json.loads((base/'launch-receipt.json').read_text())
results=json.loads((base/'results.json').read_text())
native_audit=json.loads((base/'postrun-native-audit.json').read_text())
assert native_audit['sdk_header_sha256']==receipt['sdk']['header_sha256']
assert native_audit['vendor_header_text_copied'] is False
supplement=None
if results.get('native_full_flags_supplement'):
    supplement_path=base/results['native_full_flags_supplement']
    supplement=json.loads(supplement_path.read_text())
    assert sha((supplement_path.parent/'survey.py').read_bytes())==supplement['survey_script_sha256']
    assert supplement['original_launch_receipt_sha256']==sha((base/'launch-receipt.json').read_bytes())
    assert supplement['source_head']==snapshot['source_head'] and supplement['source_tree']==snapshot['source_tree']
    assert supplement['original_sdk_inventory_count']==2 and supplement['full_observed_native_flag_inventory_count']==50
    assert len(supplement['header_sha256'])==len(supplement['header_file_stability'])==50
    assert supplement['native_command_count']==4 and len(supplement['groups'])==4
    assert supplement['simulation_or_native_rebuild_performed'] is False
    assert supplement['vendor_or_system_header_contents_copied'] is False
    assert supplement['file_stability_rechecked_after_dependency_queries'] is True
    assert supplement['all_header_mtime_and_ctime_precede_campaign_start'] is True
    for name,record in supplement['header_file_stability'].items():
        assert record['sha256']==supplement['header_sha256'][name]
        assert max(record['mtime_ns'],record['ctime_ns'])<supplement['campaign_start_epoch_ns']
    compiler=supplement['compiler_binary']
    assert max(compiler['mtime_ns'],compiler['ctime_ns'])<supplement['campaign_start_epoch_ns']
    for name,digest in receipt['sdk']['header_sha256'].items():assert supplement['header_sha256'][name]==digest
expected_windows={'common-ns':5120000,'common-cycle':5118720,'common-ns-unknown':5120000,'common-ns-reset':5119999}
if receipt.get('full_identity'):
    assert sha(json.dumps(receipt['full_identity'],sort_keys=True).encode())==receipt['full_identity_sha256']==results['full_identity_sha256']
    assert receipt['full_identity']['sdk_header_sha256']==receipt['sdk']['header_sha256']
    assert set(receipt['full_identity']['profiles'])==set(expected_windows)

def unpack(path,entry):
    compressed=path.read_bytes()
    assert sha(compressed)==entry['gzip_sha256'],path
    raw=gzip.decompress(compressed)
    assert sha(raw)==entry['uncompressed_sha256'],path
    assert len(raw)==entry['uncompressed_bytes'],path
    return raw

with tempfile.TemporaryDirectory(prefix='bw-common29-recorded-') as tmp:
    temp=Path(tmp);source=temp/'source'
    for name,entry in snapshot['files'].items():
        raw=unpack(snapshot_path.parent/entry['gzip_file'],entry)
        target=source/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        if name.startswith('rtl/'):
            assert sha(raw)==receipt['production_sha256'][name],name
            if args.current_source:assert sha((repo/name).read_bytes())==sha(raw),name
    totals={}
    for profile,window_count in expected_windows.items():
        directory=base/profile;bundle=json.loads((directory/'bundle.json').read_text())
        attempt=temp/profile;attempt.mkdir()
        content={}
        for name,entry in bundle['files'].items():
            content[name]=unpack(directory/entry['gzip_file'],entry)
            (attempt/name).write_bytes(content[name])
        manifest=json.loads(content['manifest.json'].decode());verification=json.loads(content['verification.json'].decode())
        assert manifest['source_head']==snapshot['source_head']==receipt['source_head']==results['source_head']
        assert manifest['source_tree']==snapshot['source_tree'] and not manifest['source_status']
        assert manifest['state']=='VERIFIED' and manifest['checked_pass'] is True
        assert manifest['configuration']['acceptance_profile'] and manifest['configuration']['end_ticks']==40000000000
        assert manifest['configuration']['topology']['points']==1024 and manifest['configuration']['topology']['groups']==256
        assert manifest['configuration']['expected_edges']==80000
        assert manifest['simulation']['returncode']==0 and manifest['compile']['returncode']==0
        assert manifest['verification']==verification==results['profiles'][profile]['verification']
        assert verification['checked_raw']==102400000 and verification['checked_windows']==window_count
        assert verification['observed_scopes']==1280 and verification['difference_count']==0
        assert json.loads(content['diffs.json'].decode())==[]
        for name,expected in manifest['source_sha256'].items():
            assert snapshot['files'][name]['uncompressed_sha256']==expected,name
        if receipt.get('full_identity'):
            assert manifest['source_sha256']==receipt['full_identity']['source_sha256']
        for name,expected in manifest['evidence_sha256'].items():
            assert name in content and sha(content[name])==expected,(profile,name)
        for name,expected in manifest['generated_sha256'].items():assert sha(content[name])==expected,(profile,name)
        for field,name in [('input_sha256','input.json'),('cfg_sha256','expect.cfg'),('expected_sha256','expected.csv')]:
            assert sha(content[name])==manifest[field],(profile,field)
        audit=json.loads(content['supplementary-audit.json'].decode())
        assert not audit['differences'] and audit['source_hashes']==24 and audit['checked_scopes']==1280
        native=content['native-dependencies.d'].decode()
        assert str(Path(manifest['source_snapshot'])/'rtl/bw_slot_settlement.c') in native
        for header in receipt['sdk']['header_sha256']:assert header in native,(profile,header)
        command=manifest['compile']['command']
        assert '+vpi' in command and '-debug_access' in command
        assert str(Path(manifest['source_snapshot'])/'rtl/bw_slot_settlement.c') in command
        if receipt.get('full_identity'):
            for option in receipt['full_identity']['compile_options']:assert option in command,(profile,option)
        cache=json.loads(content['compile-success.json'].decode())
        assert cache['result']==manifest['compile'] and cache['digest']==manifest['compile_digest']
        digest=sha(json.dumps(manifest['source_sha256'],sort_keys=True).encode()+
                   b''.join(content[name] for name in ('input_pkg.sv','checker.sv','tb_bw_scale.sv')))
        assert digest==manifest['compile_digest']
        postrun=native_audit['profiles'][profile]
        assert cache['binary_sha256']==postrun['simulator_sha256']
        assert sha(content['native-dependencies.d'])==postrun['native_dependencies_sha256']
        assert postrun['source_hashes_match_launch_and_current'] and postrun['sdk_header_hashes_match_launch_and_current']
        if supplement:
            matches=[group for group in supplement['groups'] if group['profile']==profile];assert len(matches)==1
            group=matches[0];full_dependencies=(supplement_path.parent/group['dependency_file']).read_bytes()
            assert sha(full_dependencies)==group['dependency_sha256']
            paths=full_dependencies.decode().replace('\\\n',' ').split(':',1)[1].split()
            assert paths[0]==str(Path(manifest['source_snapshot'])/'rtl/bw_slot_settlement.c')
            assert len(paths)==51 and sorted(set(paths[1:]))==group['header_paths']
            assert set(group['header_paths'])==set(supplement['header_sha256'])
            assert group['header_count']==50 and group['dependency_query_returncode']==0 and not group['dependency_query_stderr']
            assert group['native_dependency_sha256']==sha(content['native-dependencies.d'])
            assert group['native_object_sha256']==postrun['native_object_sha256']
            assert group['simulator_sha256']==postrun['simulator_sha256']
            assert group['actual_compile_log_sha256']==sha(content['compile.log'])
            line=content['compile.log'].decode().splitlines()[group['actual_compile_log_line']-1]
            assert line==group['actual_compile_log_line_text']
            assert shlex.split(line)==group['original_native_argv']
            assert '-O' in group['original_native_argv']
            assert group['dependency_query_argv']==group['original_native_argv'][:-2]+['-M',group['original_native_argv'][-1]]
        assert not re.search(r'(?:Warning|Error)-\[',content['compile.log'].decode())
        for stage,filename in [('compile','compile.time-v.txt'),('simulation','simulation.time-v.txt')]:
            match=re.search(r'Maximum resident set size \(kbytes\):\s+(\d+)',content[filename].decode())
            assert match and int(match.group(1))==manifest[stage]['time_v_peak_rss_kib']>0
        # Regenerate independent stimulus/reference/config/SV from the actual frozen
        # driver, then inspect every scope and final formal stream in a private copy.
        # No compile, simulator, original worktree or original absolute path is used.
        code='''import json,pathlib,sys
sys.path.insert(0,sys.argv[1])
from scenario import Scenario
from generate import generate
from run import verify
attempt=pathlib.Path(sys.argv[2]);fresh=attempt/'regenerated';fresh.mkdir()
scenario=Scenario(sys.argv[3]);generate(scenario,fresh)
for name in ('input.json','expect.cfg','expected.csv','input_pkg.sv','checker.sv','tb_bw_scale.sv'):
    assert (attempt/name).read_bytes()==(fresh/name).read_bytes(),name
before=(attempt/'verification.json').read_bytes()
passed,evidence=verify(scenario,attempt)
assert passed and evidence['difference_count']==0
assert before==(attempt/'verification.json').read_bytes()
'''
        subprocess.run([sys.executable,'-c',code,str(source/'tests/scale'),str(attempt),profile],check=True)
        for key in ('checked_raw','checked_windows','difference_count','episode_records','phase_records'):
            totals[key]=totals.get(key,0)+verification[key]
        print('PASS',profile,'1280 scopes; original/source/native/command/RSS hashes; regenerated inputs/reference; complete final streams')
    assert totals==results['totals']
    print('PASS '+base.name+' common campaign:',json.dumps(totals,sort_keys=True))
