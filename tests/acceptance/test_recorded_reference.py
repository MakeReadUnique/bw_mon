"""Frozen evidence is checked with its consumed oracle, never today's policy."""
import json
import gzip
from pathlib import Path
import tempfile
import unittest

from audit import replay_recorded_reference


class RecordedReferenceContracts(unittest.TestCase):
    def test_historical_raw_table_replays_and_rejects_a_changed_byte_count(self):
        fixture = json.loads(gzip.decompress(Path(__file__).with_name('recorded_reference_fixture.json.gz').read_bytes()))
        manifest = fixture['manifest']
        sources = {name:data.encode() for name,data in fixture['sources'].items()}
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            for name,data in fixture['files'].items():
                (work/name).write_text(data)
            result = replay_recorded_reference(sources, manifest, work)
            self.assertEqual(result['basic']['counts'],
                             dict(raw=5104, receipts=5104, windows=2560))
            rows = (work/'stimulus.txt').read_text().splitlines()
            row = rows[0].split(); row[12] = '63'; rows[0] = ' '.join(row)
            (work/'stimulus.txt').write_text('\n'.join(rows)+'\n')
            with self.assertRaises(AssertionError):
                replay_recorded_reference(sources, manifest, work)


if __name__ == '__main__':
    unittest.main()
