#!/usr/bin/env python3
"""Verify frozen assets and source applicability without granting human approval."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'evidence/verdi61/review.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    review = json.loads(REVIEW.read_text())
    archive = subprocess.check_output(
        ['git', 'archive', review['asset_commit'], 'artifacts/verdi61-data'],
        cwd=str(ROOT))
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        assets = {member.name: bundle.extractfile(member).read()
                  for member in bundle.getmembers() if member.isfile()}
    for name, digest in review['asset_sha256'].items():
        assert sha(assets[name]) == digest, ('Frozen asset differs', name)
    for name, digest in review['source_sha256'].items():
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
