"""The revised completion gate cannot inherit legacy counts or partial runs."""
import unittest
import copy
from revised_evidence import validate_suite, FULL, QUICK, COMPONENT_CASES, digest


def complete_metadata():
    return dict(schema='bw-revised-suite-v1',tier='full',cache_mode='hot',checked_pass=True,state='VERIFIED',
                elapsed_seconds=100,budget_seconds=1800,concurrency=1,expected_profiles=FULL,
                profiles=[dict(name=n,checked_pass=True) for n in FULL],component_cases=[dict(name=n) for n in COMPONENT_CASES],
                stages={n:dict(state='COMPLETED') for n in ('components','common_replay','recorded_replay')})


def bound_metadata():
    """Metadata-only fixture; native/stream replay remains a separate gate."""
    value=complete_metadata();sources={'rtl/example.sv':'fixed-source'};tools={'compiler':'fixed-tool'}
    value['freeze']=dict(source_head='fixed-head',source_status='',source_sha256=sources,tools=tools,
                         common_profile_sources=list(sources),source_digest=digest(sources),tools_digest=digest(tools))
    value.update(started_utc='2026-10-26T00:00:00Z',finished_utc='2026-10-26T00:00:14Z',elapsed_seconds=14,
                 orchestration_seconds=0,freeze_unchanged=dict(source=True,tools=True,checkout=True,common=True))
    runs={}
    for i,row in enumerate(value['profiles']):
        row['manifest']='/recorded/'+row['name']+'/manifest.json'
        runs[row['name']]=dict(scenario=row['name'],checked_pass=True,state='VERIFIED',source_head='fixed-head',source_status='',
             source_sha256=dict(sources),build_identity=dict(tools=tools),build_receipt_sha256='immutable-receipt',
             elapsed_seconds=1,budget_seconds=300,started_utc='2026-10-26T00:00:{:02d}Z'.format(i),
             finished_utc='2026-10-26T00:00:{:02d}Z'.format(i+1))
    for i,name in enumerate(('components','common_replay','recorded_replay'),11):
        value['stages'][name].update(elapsed_seconds=1,started_utc='2026-10-26T00:00:{:02d}Z'.format(i),
                                   finished_utc='2026-10-26T00:00:{:02d}Z'.format(i+1))
    return value,runs


class RevisedCompletion(unittest.TestCase):
    def test_valid_metadata_requires_matching_serial_source_bound_receipts(self):
        value,runs=bound_metadata()
        validate_suite(value,expected_key='full-hot',run_loader=lambda row:runs[row['name']])
        wrong=copy.deepcopy(runs);wrong[FULL[1]]['scenario']=FULL[0]
        with self.assertRaisesRegex(ValueError,'actual run'):
            validate_suite(value,run_loader=lambda row:wrong[row['name']])
        wrong=copy.deepcopy(runs);wrong[FULL[1]]['build_identity']['tools']['compiler']='changed'
        with self.assertRaisesRegex(ValueError,'tools'):
            validate_suite(value,run_loader=lambda row:wrong[row['name']])
        wrong=copy.deepcopy(runs);wrong[FULL[1]]['elapsed_seconds']=10
        with self.assertRaisesRegex(ValueError,'interval'):
            validate_suite(value,run_loader=lambda row:wrong[row['name']])

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

    def test_each_profile_requires_its_own_matching_receipt(self):
        value=complete_metadata()
        for row in value['profiles']:
            row['manifest']='/same/topology-quick-ns/manifest.json'
        with self.assertRaises(ValueError):
            validate_suite(value)

    def test_suite_duration_includes_required_stage_duration(self):
        value=complete_metadata();value['stages']['components']['elapsed_seconds']=2000
        with self.assertRaises(ValueError):
            validate_suite(value)

    def test_hot_archive_key_cannot_carry_a_cold_budget(self):
        value=complete_metadata()
        value.update(tier='quick',cache_mode='cold',elapsed_seconds=250,budget_seconds=300,
                     expected_profiles=QUICK,profiles=[dict(name=n,checked_pass=True) for n in QUICK],
                     stages={'recorded_replay':dict(state='COMPLETED')})
        with self.assertRaises(ValueError):
            validate_suite(value,expected_key='quick-hot')


if __name__=='__main__':
    unittest.main()
