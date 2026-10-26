#!/usr/bin/env python3
"""Verify saved analog views and capture receipts without launching simulation or GUI."""
import hashlib
import json
from pathlib import Path
import struct
import tarfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    meta = json.loads((HERE / 'views.json').read_text())
    audit = json.loads((HERE / 'verification.json').read_text())
    frozen = json.loads((HERE.parent / 'acceptance/verification.json').read_text())
    assert meta['source_asset_commit'] == frozen['asset_commit'] == audit['source_asset_commit']
    assert meta['source_asset_fingerprint'] == frozen['asset_fingerprint']
    fsdb_hashes = {scene['scene']: scene['fsdb_sha256'] for scene in frozen['scenes']}
    archive_path = HERE / 'capture-provenance.tar.gz'
    assert sha(archive_path) == audit['capture_archive_sha256']
    with tarfile.open(str(archive_path)) as archive:
        baseline = json.load(archive.extractfile('frozen-before.json'))
        for path, digest in baseline.items():
            assert sha(ROOT / path) == digest, 'Frozen file changed: ' + path
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
    print('PASS: %d fresh native analog captures, portable reopens, and %d unchanged frozen files.'
          % (len(meta['views']), len(baseline)))


if __name__ == '__main__':
    main()
