#!/usr/bin/env python3
"""Exercise real scene generation, publication and packed audit in a disposable checkout."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AcceptanceReproductionCLI(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='bw-acceptance-reproduce-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ['rtl', 'tests/acceptance', 'artifacts/acceptance']:
            shutil.copytree(str(ROOT / name), str(self.root / name),
                            ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copyfile(str(ROOT / '.gitignore'), str(self.root / '.gitignore'))
        native = self.root / 'rtl/bw_slot_settlement.c'
        native.write_text('/* Actual disposable provenance fixture source. */\n' + native.read_text())
        self.out = self.root / 'artifacts/acceptance'
        self.scene = self.out / 'no_episode_cycle'
        self.cli(['git', 'init', '-q'])
        self.cli(['git', 'add', 'rtl', 'tests/acceptance'])
        self.cli(['git', '-c', 'user.name=Contract Fixture', '-c',
                  'user.email=fixture@example.invalid', 'commit', '-qm',
                  'Actual project source for disposable acceptance CLI regression'])

    def cli(self, args):
        result = subprocess.run(args, cwd=str(self.root), stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, universal_newlines=True,
                                timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def script(self, name, *args):
        return self.cli([sys.executable, 'tests/acceptance/' + name + '.py'] + list(args))

    def test_generated_scene_publishes_and_audits_after_packing_without_its_build(self):
        self.script('run', '--scene', 'no_episode', '--basis', 'cycle')
        manifest = json.loads((self.scene / 'commands.json').read_text())
        self.assertIn('runtime_evidence', manifest)
        self.assertTrue((self.scene / 'native-dependencies.d').is_file())
        self.assertEqual(manifest['base_revision'], self.cli(['git', 'rev-parse', 'HEAD']).strip())
        self.assertEqual(manifest['dependency_sha256']['rtl/bw_stats_core.sv'],
                         hashlib.sha256((self.root / 'rtl/bw_stats_core.sv').read_bytes()).hexdigest())
        self.script('publish', '--pack')
        shutil.rmtree(str(self.root / '.build'))
        self.assertIn('PASS portable42sceneaudit', self.script('audit'))
        verification = json.loads((self.out / 'verification.json').read_text())
        self.assertEqual(verification['human_review'], 'PENDING')
        self.assertFalse(verification['runtime_source_unchanged'])
        self.assertIsNone(verification['production_base'])
        self.assertEqual(len(verification['production_sources']), 2)
        self.assertEqual(json.loads((self.out / 'review.json').read_text())['human']['status'], 'PENDING')

    def test_native_transitive_header_and_compile_options_each_invalidate_the_cached_build(self):
        parent = self.root / 'rtl/reproduction_parent.h'
        leaf = self.root / 'rtl/reproduction_leaf.h'
        parent.write_text('#include "reproduction_leaf.h"\n')
        leaf.write_text('#define REPRODUCTION_HEADER_VALUE 1\n')
        native = self.root / 'rtl/bw_slot_settlement.c'
        native.write_text('#include "reproduction_parent.h"\n' + native.read_text())
        self.script('run', '--scene', 'no_episode', '--basis', 'cycle')
        first = json.loads((self.scene / 'commands.json').read_text())
        receipt = first['runtime_evidence']
        dependency = next(name for name in receipt['native_transitive_dependencies_sha256']
                          if name.endswith('/reproduction_leaf.h'))
        self.assertEqual(receipt['native_transitive_dependencies_sha256'][dependency],
                         hashlib.sha256(leaf.read_bytes()).hexdigest())
        leaf.write_text('#define REPRODUCTION_HEADER_VALUE 2\n')
        self.script('run', '--scene', 'no_episode', '--basis', 'cycle')
        second = json.loads((self.scene / 'commands.json').read_text())
        self.assertNotEqual(receipt['compile_fingerprint_sha256'],
                            second['runtime_evidence']['compile_fingerprint_sha256'])
        self.assertNotEqual(first['run'][0], second['run'][0])
        self.assertEqual((Path(first['source_snapshot']) / 'rtl/reproduction_leaf.h').read_text(),
                         '#define REPRODUCTION_HEADER_VALUE 1\n')
        self.script('run', '--scene', 'no_episode', '--basis', 'cycle',
                    '--cflags=-DBW_REPRODUCTION_OPTION=1')
        third = json.loads((self.scene / 'commands.json').read_text())
        self.assertNotEqual(second['runtime_evidence']['compile_fingerprint_sha256'],
                            third['runtime_evidence']['compile_fingerprint_sha256'])
        self.assertIn('-DBW_REPRODUCTION_OPTION=1', (self.scene / 'compile.log').read_text())
        # Publication validates the actual receipts before resolving any new FSDB.
        manifest_path = self.scene / 'commands.json'
        dependency = next(name for name in third['runtime_evidence']['native_transitive_dependencies_sha256']
                          if name.endswith('/reproduction_leaf.h'))
        third['runtime_evidence']['native_transitive_dependencies_sha256'][dependency] = '0' * 64
        manifest_path.write_text(json.dumps(third, indent=2) + '\n')
        result = subprocess.run([sys.executable, 'tests/acceptance/publish.py'], cwd=str(self.root),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                universal_newlines=True, timeout=120)
        self.assertNotEqual(result.returncode, 0, result.stdout)



if __name__ == '__main__':
    unittest.main(verbosity=2)
