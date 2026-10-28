"""Build immutable acceptance snapshots and record the actual compiler dependencies."""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tarfile
from evidence import canonical_sha, make_dependencies, sha


def output(command, cwd):
    return subprocess.check_output(command, cwd=str(cwd), universal_newlines=True)


def project_name(path, root):
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def prepare(root, top, sources, cflags=''):
    include = Path(shutil.which('vcs')).resolve().parents[1] / 'include'
    native_flags = ['-fPIC', '-O', '-I' + str(include)] + shlex.split(cflags)
    native_sources = [p for p in sources if p.suffix == '.c']
    assert len(native_sources) == 1, 'acceptance native dependency contract requires one native source'
    discovery = ['gcc', '-M'] + native_flags + [str(native_sources[0])]
    native_paths = [Path(p).resolve() for p in make_dependencies(output(discovery, root))]
    project = set(sources)
    project.update(p for p in (root / 'rtl').rglob('*') if p.suffix in ['.svh', '.vh', '.h'])
    project.update(root / 'tests/acceptance' / name for name in
                   ['run.py', 'model.py', 'analysis.py', 'summarize.py', 'build.py', 'evidence.py'])
    project.update(p for p in native_paths if project_name(p, root) != str(p))
    project_hashes = {str(p.relative_to(root)): sha(p) for p in sorted(project)}
    native_hashes = {project_name(p, root): sha(p) for p in native_paths[1:]}
    template = ['vcs', '-full64', '-error=AOUP', '-sverilog', '+vpi', '-debug_access+all', '-kdb',
                '-CFLAGS', '-I' + str(include) + (' ' + cflags if cflags else ''),
                '+incdir+@SOURCE@/rtl', '-assert', 'svaext', '-top', top, '-o', '@BUILD@/simv']
    template += ['@SOURCE@/' + str(p.relative_to(root)) for p in sources]
    vcs_id = output(['vcs', '-ID'], root)
    fingerprint = {
        'checkout_root': str(root),
        'command': template, 'project_sha256': project_hashes,
        'native_header_sha256': native_hashes,
        'tools': {'vcs': str(Path(shutil.which('vcs')).resolve()),
                  'vcs_sha256': sha(Path(shutil.which('vcs')).resolve()),
                  'vcs_version': re.search(r'^Compiler version = (.*)$', vcs_id, re.M).group(1),
                  'gcc': str(Path(shutil.which('gcc')).resolve()),
                  'gcc_sha256': sha(Path(shutil.which('gcc')).resolve()),
                  'gcc_version': output(['gcc', '--version'], root).splitlines()[0]},
        'environment': {key: os.environ.get(key, '') for key in
                        ['VCS_HOME', 'VERDI_HOME', 'NOVAS_HOME', 'VCS_CC', 'VCS_CXX',
                         'CC', 'CXX', 'CFLAGS', 'LD_LIBRARY_PATH']},
    }
    digest = canonical_sha(fingerprint)
    build = root / '.build/acceptance' / top / digest
    snapshot = build / 'source'
    snapshot.mkdir(parents=True, exist_ok=True)
    for name, expected in project_hashes.items():
        target = snapshot / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copyfile(str(root / name), str(target))
        assert sha(target) == expected, ('immutable source snapshot differs', target)
    command = [arg.replace('@SOURCE@', str(snapshot)).replace('@BUILD@', str(build)) for arg in template]
    return build, snapshot, command, fingerprint, native_flags


def receipt(root, out, build, snapshot, command, fingerprint, native_flags):
    # This .d comes from VCS's actual native compilation, not from a fabricated list.
    actual = build / 'csrc/bw_slot_settlement.d'
    shutil.copyfile(str(actual), str(out / 'native-dependencies.d'))
    source = snapshot / 'rtl/bw_slot_settlement.c'
    dependency_command = ['gcc', '-M'] + native_flags + [str(source)]
    full = output(dependency_command, build)
    (out / 'native-transitive-dependencies.d').write_text(full)
    native = make_dependencies(actual.read_text())
    transitive = make_dependencies(full)
    assert native[0] == transitive[0] == str(source), 'native receipt names a different source snapshot'
    normalized = {}
    for name in transitive[1:]:
        path = Path(name)
        normalized[project_name(path, snapshot)] = sha(path)
    assert normalized == fingerprint['native_header_sha256'], 'native headers changed during compilation'
    archive = out / 'source.tar.gz'
    with tarfile.open(str(archive), 'w:gz') as bundle:
        for name, expected in sorted(fingerprint['project_sha256'].items()):
            assert sha(snapshot / name) == expected, ('compiled source snapshot changed', name)
            bundle.add(str(snapshot / name), arcname=name, recursive=False)
    return {
        'schema_version': 2,
        'runtime_head': output(['git', 'rev-parse', 'HEAD'], root).strip(),
        'checkout_tree': output(['git', 'rev-parse', 'HEAD^{tree}'], root).strip(),
        'checkout_project_changes': output(['git', 'status', '--porcelain', '--', 'rtl', 'tests/acceptance'], root).splitlines(),
        'source_snapshot_sha256': {name: digest for name, digest in fingerprint['project_sha256'].items() if name.startswith('rtl/')},
        'source_archive': archive.name, 'source_archive_sha256': sha(archive),
        'compile_fingerprint': fingerprint, 'compile_fingerprint_sha256': canonical_sha(fingerprint),
        'build_directory': str(build),
        'native_dependency_makefile_sha256': sha(out / 'native-dependencies.d'),
        'native_dependencies_sha256': {name: sha(name) for name in native[1:]},
        'native_transitive_dependency_command': dependency_command,
        'native_transitive_makefile_sha256': sha(out / 'native-transitive-dependencies.d'),
        'native_transitive_dependencies_sha256': {name: sha(name) for name in transitive[1:]},
    }
