#!/usr/bin/env python3
"""Verify saved analog views and capture receipts without launching simulation or GUI."""
import hashlib
import json
from pathlib import Path
import struct
import tarfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
# These four publisher outputs describe current review status. Every other
# archived byte remains bound to the original capture-generation inventory.
CURRENT_SUMMARIES = {'review.json', 'verification.json', 'INDEX.md', 'SHA256SUMS.json'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    meta = json.loads((HERE / 'views.json').read_text())
    audit = json.loads((HERE / 'verification.json').read_text())
    acceptance = HERE.parent / 'acceptance'
    frozen = json.loads((acceptance / 'verification.json').read_text())
    ledger = json.loads((acceptance / 'review.json').read_text())
    inventory = json.loads((acceptance / 'SHA256SUMS.json').read_text())
    actual_files = {str(path.relative_to(acceptance)) for path in acceptance.rglob('*')
                    if path.is_file() and path.name != 'SHA256SUMS.json'}
    assert set(inventory) == actual_files, 'Incomplete current acceptance inventory'
    for name, digest in inventory.items():
        assert sha(acceptance / name) == digest, 'Current inventory mismatch: ' + name
    assert ledger['asset_fingerprint'] == meta['source_asset_fingerprint']
    assert frozen['human_review'] == ledger['human']['status'], 'Current human status differs'
    if ledger['human']['status'] != 'PENDING':
        for name, digest in ledger['human'].get('artifact_sha256', {}).items():
            path = Path(name)
            assert not path.is_absolute() and '..' not in path.parts, 'Invalid review artifact path'
            assert sha(ROOT / path) == digest, 'Named review artifact changed: ' + name
    # These are historical generation receipts, not the current human ledger.
    assert meta['human_review'] == audit['human_review'] == 'PENDING'
    assert meta['source_asset_commit'] == frozen['asset_commit'] == audit['source_asset_commit']
    assert meta['source_asset_fingerprint'] == frozen['asset_fingerprint']
    fsdb_hashes = {scene['scene']: scene['fsdb_sha256'] for scene in frozen['scenes']}
    archive_path = HERE / 'capture-provenance.tar.gz'
    assert sha(archive_path) == audit['capture_archive_sha256']
    with tarfile.open(str(archive_path)) as archive:
        baseline = json.load(archive.extractfile('frozen-before.json'))
        protected_count = 0
        for path, digest in baseline.items():
            relative = str(Path(path).relative_to('artifacts/acceptance'))
            if relative in CURRENT_SUMMARIES:
                continue
            assert sha(ROOT / path) == digest, 'Frozen file changed: ' + path
            protected_count += 1
        for name, view in meta['views'].items():
            receipt = json.loads((HERE / (name + '.receipt.json')).read_text())
            assert receipt['human_review'] == 'PENDING'
            assert receipt['agent_visual_review'] == 'PASS'
            assert receipt['fsdb_sha256'] == view['fsdb_sha256'] == fsdb_hashes[view['scene']]
            assert sha((HERE / view['fsdb']).resolve()) == view['fsdb_sha256']
            for suffix, key in [('.png', 'png_sha256'), ('.sav', 'sav_sha256'),
                                ('.reopened.sav', 'reopened_sav_sha256')]:
                assert sha(HERE / (name + suffix)) == receipt[key]
            png = (HERE / (name + '.png')).read_bytes()
            assert png[:8] == b'\x89PNG\r\n\x1a\n'
            assert list(struct.unpack('>II', png[16:24])) == view['pixels']
            saved = (HERE / (name + '.reopened.sav')).read_text()
            signals = [line for line in saved.splitlines() if line.startswith('addSignal ')]
            assert len(signals) == len(view['rows']) == receipt['restored_signal_rows']
            analog = [line for line in signals if '-w analog' in line]
            assert len(analog) == 2 and all('-ds pwc' in line for line in analog)
            assert 'windowTimeUnit 1ns' in saved
            assert all(value['matches'] for value in receipt['independent_checkpoints'])
            for file_name, key in [('capture.tcl', 'capture_tcl_sha256'),
                                   ('capture.log', 'raw_capture_log_sha256'),
                                   ('reopened.sav', 'raw_reopened_sav_sha256')]:
                content = archive.extractfile(name + '/' + file_name).read()
                assert hashlib.sha256(content).hexdigest() == receipt[key]
    print('PASS: %d fresh native analog captures, portable reopens, and %d unchanged generation files; '
          'current inventory valid; named human status=%s.'
          % (len(meta['views']), protected_count, ledger['human']['status']))


if __name__ == '__main__':
    main()
