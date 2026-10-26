"""The revised completion gate cannot inherit legacy counts or partial runs."""
import unittest
from revised_evidence import validate_suite, FULL, COMPONENT_CASES


def complete_metadata():
    return dict(schema='bw-revised-suite-v1',tier='full',cache_mode='hot',checked_pass=True,state='VERIFIED',
                elapsed_seconds=100,budget_seconds=1800,concurrency=1,expected_profiles=FULL,
                profiles=[dict(name=n,checked_pass=True) for n in FULL],component_cases=[dict(name=n) for n in COMPONENT_CASES],
                stages={n:dict(state='COMPLETED') for n in ('components','common_replay','recorded_replay')})


class RevisedCompletion(unittest.TestCase):
    def test_legacy_four_or_twelve_completion_counts_are_not_revised_evidence(self):
        for count in (4,6,12):
            with self.assertRaisesRegex(ValueError,'legacy'):
                validate_suite(dict(completed=count,checked_pass=True))

    def test_missing_or_duplicate_profile_rejects_otherwise_completed_metadata(self):
        value=complete_metadata();value['profiles'][-1]=value['profiles'][0]
        with self.assertRaisesRegex(ValueError,'profile'):
            validate_suite(value)

    def test_timeout_and_missing_independent_replay_do_not_pass(self):
        value=complete_metadata();value['elapsed_seconds']=1800.01
        with self.assertRaisesRegex(ValueError,'budget'):
            validate_suite(value)
        value=complete_metadata();del value['stages']['recorded_replay']
        with self.assertRaisesRegex(ValueError,'audits'):
            validate_suite(value)


if __name__=='__main__':
    unittest.main()
