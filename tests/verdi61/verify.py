#!/usr/bin/env python3
"""Verify frozen assets and source applicability without granting human approval."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
from decimal import Decimal
from compare import canonical_trace

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'evidence/verdi61/review.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def snapshot(revision, prefix):
    archive=subprocess.check_output(['git','archive',revision,prefix],cwd=str(ROOT))
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        return {member.name:bundle.extractfile(member).read()
                for member in bundle.getmembers() if member.isfile()}


def source_expectations(review, accepted):
    applicability=review.get('source_applicability')
    if not applicability:return review['source_sha256']
    prefix=applicability['path'].rstrip('/')+'/'
    packed=snapshot(applicability['commit'],applicability['path'])
    files={name[len(prefix):]:data for name,data in packed.items() if name.startswith(prefix)}
    assert sha(files['applicability.json'])==applicability['manifest_sha256']
    proof=json.loads(files['applicability.json'])
    assert proof['schema']=='bw-verdi-source-applicability-v1' and proof['state']=='VERIFIED'
    assert proof['accepted_asset_commit']==review['asset_commit']
    assert proof['accepted_runtime_base']==review['runtime_base']
    assert proof['original_source_sha256']==review['source_sha256']
    assert set(files)-{'applicability.json'}==set(proof['files_sha256'])
    for name,digest in proof['files_sha256'].items():assert sha(files[name])==digest,name
    for name,digest in proof['verification_tool_sha256'].items():assert sha((ROOT/name).read_bytes())==digest,name
    expected=proof['current_source_sha256']
    assert set(expected)==set(review['source_sha256'])
    changed={name for name,digest in expected.items() if digest!=review['source_sha256'][name]}
    assert changed=={'rtl/bw_default_check.svh','rtl/bw_group_mon.sv','rtl/bw_mon_transport.svh',
                     'tests/verdi61/verify.py'},changed
    # Reuse the established native source/option/dependency audit. The checker
    # capture receipt lacks scene-only keys, which can be derived from its
    # immutable compile fingerprint without changing any recorded bytes.
    module=importlib.util.spec_from_file_location('bw_acceptance_evidence',ROOT/'tests/acceptance/evidence.py')
    evidence=importlib.util.module_from_spec(module);module.loader.exec_module(evidence)
    with tempfile.TemporaryDirectory(prefix='verdi61-applicability-') as temporary:
        work=Path(temporary)
        for name,data in files.items():
            relative=Path(name)
            assert not relative.is_absolute() and '..' not in relative.parts,name
            target=work/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        for scene,run in proof['scene_runs'].items():
            manifest=json.loads(files[run['files']['commands.json']])
            native=manifest['runtime_evidence']
            project=native['compile_fingerprint']['project_sha256']
            assert set(project)<=set(expected)
            assert all(expected[name]==digest for name,digest in project.items()),scene
            if 'source_snapshot' not in manifest:
                manifest=dict(manifest,source_snapshot=native['build_directory']+'/source',
                              base_revision=native['runtime_head'],
                              dependency_sha256=native['compile_fingerprint']['project_sha256'])
            actual=evidence.scene_runtime_evidence(ROOT,work,work/scene,manifest,{})
            assert actual['rtl_sha256']==run['compiled_rtl_sha256']
            assert actual['rtl_sha256']=={n:d for n,d in expected.items() if n.startswith('rtl/')}
            assert sha(files[run['files']['waves.fsdb']])==run['new_fsdb_sha256']
            assert sha(accepted['artifacts/verdi61-data/'+scene+'/waves.fsdb'])==run['old_fsdb_sha256']
            before=[line for line in accepted['artifacts/verdi61-data/'+scene+'/run.log'].decode().splitlines()
                    if line.startswith('BW_DEFAULT_CHECK ')]
            after=[line for line in files[run['files']['run.log']].decode().splitlines()
                   if line.startswith('BW_DEFAULT_CHECK ')]
            assert before==after and len(after)==run['identical_default_check_rows'],scene
    recorded={v['name']:v for v in proof['views']}
    assert len(recorded)==len(proof['views'])==len(review['views'])
    for view in review['views']:
        entry=recorded[view['name']]
        begin,end=[int(Decimal(str(n))*1000000) for n in view['range_ns']]
        assert entry['range_fs']==[begin,end] and entry['scene']==view['scene']
        assert entry['signals']==sorted(view['expected_values'])
        assert entry['accepted_image_sha256']==view['image_sha256']
        assert entry['accepted_fsdb_sha256']==view['fsdb_sha256']
        traces={}
        for role in ['accepted','current']:
            trace={}
            for scope in {p.rsplit('/',1)[0] for p in view['expected_values']}:
                receipt=proof['exports'][view['scene']][role][scope]
                assert receipt['exit_code']==0
                command=receipt['command']
                assert all(flag in command for flag in ['-seq','-sv','-keep_last_time','-s'])
                assert command[command.index('-s')+1]==scope
                assert sha(files[receipt['vcd']])==receipt['vcd_sha256']
                run=proof['scene_runs'][view['scene']]
                assert receipt['fsdb_sha256']==run['old_fsdb_sha256' if role=='accepted' else 'new_fsdb_sha256']
                paths=[p for p in view['expected_values'] if p.rsplit('/',1)[0]==scope]
                trace.update(canonical_trace(files[receipt['vcd']].decode(),paths,begin,end))
            traces[role]=trace
        assert traces['accepted']==traces['current'],view['name']
        assert sha(json.dumps(traces['current'],sort_keys=True,separators=(',',':')).encode())==entry['identical_trace_sha256']
    return expected


def main():
    review = json.loads(REVIEW.read_text())
    assets=snapshot(review['asset_commit'],'artifacts/verdi61-data')
    for name, digest in review['asset_sha256'].items():
        assert sha(assets[name]) == digest, ('Frozen asset differs', name)
    expected=source_expectations(review,assets)
    assert all(str(p.relative_to(ROOT)) in expected for p in (ROOT/'rtl').rglob('*') if p.is_file())
    for name, digest in expected.items():
        assert sha((ROOT / name).read_bytes()) == digest, (
            'Source changed; assess affected views and renew their feedback', name)
    for view in review['views']:
        name = view['image']
        assert sha((ROOT / name).read_bytes()) == view['image_sha256'], (
            'Reviewed image changed; renew feedback for this view', name)
        assert view['expected_values'] == view['actual_values'], name
        scene = 'artifacts/verdi61-data/' + view['scene'] + '/'
        assert sha(assets[scene + 'waves.fsdb']) == view['fsdb_sha256'], name
    # Re-run the unchanged independent public-input oracle against both frozen
    # product logs, rather than accepting a saved PASS string on its own.
    with tempfile.TemporaryDirectory(prefix='verdi61-verify-') as temporary:
        for mode in ['constant', 'alternating']:
            log = Path(temporary) / (mode + '.log')
            log.write_bytes(assets['artifacts/verdi61-data/' + mode + '/run.log'])
            subprocess.run([sys.executable, str(ROOT / 'tests/checker_default/check.py'),
                            str(log), mode], check=True)
    print('PASS frozen assets, four native views and current-source applicability; '
          'human review: ' + review['human']['status'])


if __name__ == '__main__':
    main()
