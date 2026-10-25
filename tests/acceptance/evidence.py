"""Validate consumed project snapshots and recorded native dependency receipts.

Historical campaigns keep their original source identity. Recorded-data audits
use archived project bytes and native hashes; recompilation discovers and checks
the installed SDK/system headers afresh. Vendor headers are never vendored here.
"""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys
import tarfile

HISTORICAL_RUNTIME_HEAD = '8e81839423ab7db335365a5e577e25b2ebe5dcb0'
HISTORICAL_SOURCE = 'historical-source-8e81839.tar.gz'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def make_dependencies(text):
    return shlex.split(text.replace('\\\n', ' ').split(':', 1)[1])


def archive_files(path):
    files = {}
    with tarfile.open(str(path)) as archive:
        for member in archive.getmembers():
            name = Path(member.name)
            assert member.isfile() and not name.is_absolute() and '..' not in name.parts, ('unexpected source archive path', member.name)
            assert member.name not in files, ('duplicate archived source', member.name)
            files[member.name] = archive.extractfile(member).read()
    return files


def runtime_sources(root):
    return {str(p.relative_to(root)): sha(p) for p in (root / 'rtl').rglob('*')
            if p.suffix in ['.sv', '.svh', '.vh', '.c', '.h']}


def runtime_evidence(root, out):
    # This is explicitly the retained historical proof, never a proof for new source.
    freeze = json.loads((out / 'runtime-source.json').read_text())
    assert freeze['head'] == HISTORICAL_RUNTIME_HEAD, ('unexpected historical runtime freeze', freeze['head'])
    files = archive_files(out / HISTORICAL_SOURCE)
    for name, digest in freeze['rtl_sha256'].items():
        assert hashlib.sha256(files[name]).hexdigest() == digest, ('historical runtime source changed', name)
    native = freeze['native_header_dependencies']
    assert {Path(name).name for name in native['vendor_headers']} == {'svdpi.h', 'vpi_user.h'}
    proof = out / 'current-component-proof'
    current = json.loads((proof / 'verification.json').read_text())
    assert current['source_head'] == freeze['head'] and current['cases'] == current['runtime_contracts_verified']
    result = subprocess.run([sys.executable, str(proof / 'verify.py')], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, universal_newlines=True)
    assert result.returncode == 0, ('historical component proof', result.stdout)
    return freeze


def project_sources(out, folder, manifest):
    native = manifest['runtime_evidence']
    if native.get('schema_version', 1) == 2:
        path = folder / native['source_archive']
        assert path.name == native['source_archive'], 'source archive must be beside its scene'
        assert sha(path) == native['source_archive_sha256'], ('source archive changed', folder.name)
    else:
        path = out / HISTORICAL_SOURCE
    files = archive_files(path)
    expected = {name: digest for name, digest in manifest['dependency_sha256'].items() if name.startswith(('rtl/', 'tests/'))}
    assert set(files) == set(expected), ('incomplete project source archive', folder.name)
    for name, digest in expected.items():
        reason = 'scene consumed a different runtime' if name.startswith('rtl/') else 'stale simulation/reference source'
        assert hashlib.sha256(files[name]).hexdigest() == digest, (reason, folder.name, name)
    return files


def dependency_bytes(root, out, folder, manifest, name):
    if name.startswith(('rtl/', 'tests/')):
        return project_sources(out, folder, manifest)[name]
    path = root / name
    if path.is_file():
        return path.read_bytes()
    assert name.endswith('/stimulus.txt'), ('missing scene input', name)
    with tarfile.open(str(folder / 'trace.tar.gz')) as archive:
        return archive.extractfile('stimulus.txt').read()


def scene_runtime_evidence(root, out, folder, manifest, freeze):
    native = manifest['runtime_evidence']
    files = project_sources(out, folder, manifest)
    sources = {name: hashlib.sha256(data).hexdigest() for name, data in files.items() if name.startswith('rtl/')}
    dependency_file = folder / 'native-dependencies.d'
    assert sha(dependency_file) == native['native_dependency_makefile_sha256'], ('native dependency receipt changed', folder.name)
    dependencies = make_dependencies(dependency_file.read_text())
    assert dependencies[0].endswith('/rtl/bw_slot_settlement.c'), ('unexpected native source', folder.name)
    command = manifest['compile']
    assert '+vpi' in command and any(x in command for x in ['-debug_access', '-debug_access+all'])
    assert '-CFLAGS' in command and any(name.endswith('/rtl/bw_slot_settlement.c') for name in command)
    assert len(manifest['base_revision']) == 40, ('missing actual checkout revision', folder.name)
    if native.get('schema_version', 1) == 1:
        for name, digest in freeze['rtl_sha256'].items():
            assert sources.get(name) == digest, ('scene consumed a different runtime', folder.name, name)
        sdk = freeze['native_header_dependencies']['vendor_headers']
        assert native['native_dependencies_sha256'] == {name: freeze['native_header_dependencies']['header_sha256'][name] for name in sdk}, ('native header changed', folder.name)
        assert native['runtime_head'] == freeze['head']
        assert native['freeze_sha256'] == sha(out / 'runtime-source.json')
        assert native['source_snapshot_sha256'] == sources, ('compiled snapshot changed', folder.name)
        assert len(dependencies) == 3 and set(dependencies[1:]) == set(sdk)
        assert '-I' + str(Path(sdk[0]).parent) in command
    else:
        assert native['schema_version'] == 2, ('unsupported runtime evidence version', folder.name)
        assert dependencies[0] == str(Path(manifest['source_snapshot']) / 'rtl/bw_slot_settlement.c'), ('native receipt names a different source snapshot', folder.name)
        assert native['runtime_head'] == manifest['base_revision']
        assert native['source_snapshot_sha256'] == sources, ('compiled snapshot changed', folder.name)
        fingerprint = native['compile_fingerprint']
        assert canonical_sha(fingerprint) == native['compile_fingerprint_sha256'], ('compile fingerprint changed', folder.name)
        assert fingerprint['project_sha256'] == {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
        expected_command = [arg.replace('@SOURCE@', manifest['source_snapshot']).replace('@BUILD@', native['build_directory']) for arg in fingerprint['command']]
        assert command == expected_command, ('compile options changed', folder.name)
        assert set(native['native_dependencies_sha256']) == set(dependencies[1:])
        full = folder / 'native-transitive-dependencies.d'
        assert sha(full) == native['native_transitive_makefile_sha256'], ('transitive native receipt changed', folder.name)
        transitive = make_dependencies(full.read_text())
        assert transitive[0] == dependencies[0]
        hashes = native['native_transitive_dependencies_sha256']
        assert set(hashes) == set(transitive[1:])
        assert all(hashes.get(name) == digest for name, digest in native['native_dependencies_sha256'].items())
        normalized = {}
        snapshot = Path(manifest['source_snapshot'])
        for name, digest in hashes.items():
            try:
                key = str(Path(name).relative_to(snapshot))
                assert hashlib.sha256(files[key]).hexdigest() == digest, ('native project header changed', key)
            except ValueError:
                key = name
            normalized[key] = digest
        assert normalized == fingerprint['native_header_sha256'], ('native header fingerprint changed', folder.name)
        assert {Path(name).name for name in hashes}.issuperset({'svdpi.h', 'vpi_user.h'})
    return {'head': native['runtime_head'], 'rtl_sha256': sources}
