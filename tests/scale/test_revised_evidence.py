"""The revised completion gate cannot inherit legacy counts or partial runs."""
import unittest
import copy
import datetime
import json
import tempfile
import subprocess
import sys
from pathlib import Path
from revised_evidence import validate_suite, validate_run_metadata, utc_seconds, FULL, QUICK, COMPONENT_CASES, digest
from revised_evidence import validate_source_bound_verification,sha


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
    total=len(FULL)+3
    value.update(started_utc='2026-10-26T00:00:00Z',
                 finished_utc='2026-10-26T00:00:{:02d}Z'.format(total),elapsed_seconds=total,
                 orchestration_seconds=0,freeze_unchanged=dict(source=True,tools=True,checkout=True,common=True))
    runs={}
    for i,row in enumerate(value['profiles']):
        row['manifest']='/recorded/'+row['name']+'/manifest.json'
        runs[row['name']]=dict(scenario=row['name'],checked_pass=True,state='VERIFIED',source_head='fixed-head',source_status='',
             source_sha256=dict(sources),build_identity=dict(tools=tools),build_receipt_sha256='immutable-receipt',
             elapsed_seconds=1,budget_seconds=300,started_utc='2026-10-26T00:00:{:02d}Z'.format(i),
             finished_utc='2026-10-26T00:00:{:02d}Z'.format(i+1))
        run=runs[row['name']];base='2026-10-26T00:00:{:02d}'.format(i)
        run['compile_reused']=False
        boundaries=[run['started_utc'],base+'.100000Z',base+'.300000Z',base+'.800000Z',run['finished_utc']]
        run['stages']={name:dict(state='COMPLETED',returncode=0,elapsed_seconds=elapsed,
                                started_utc=boundaries[j],finished_utc=boundaries[j+1])
                       for j,(name,elapsed) in enumerate(zip(('generation','compile','simulation','verification'),(.1,.2,.5,.2)))}
    for i,name in enumerate(('components','common_replay','recorded_replay'),len(FULL)):
        value['stages'][name].update(elapsed_seconds=1,started_utc='2026-10-26T00:00:{:02d}Z'.format(i),
                                   finished_utc='2026-10-26T00:00:{:02d}Z'.format(i+1))
    return value,runs


class RevisedCompletion(unittest.TestCase):
    def test_portable_verifier_starts_without_checkout_modules(self):
        with tempfile.TemporaryDirectory() as temporary:
            script=Path(temporary)/'verify.py'
            script.write_bytes(Path(__file__).with_name('revised_evidence.py').read_bytes())
            result=subprocess.run([sys.executable,'-I',str(script),'--help'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            self.assertEqual(result.returncode,0,result.stderr.decode())

    def test_original_source_bound_audit_cannot_be_reused_or_hide_changed_raw_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            out=Path(temporary)
            for name,text in {'input.json':'fixed input','simulation.log':'actual run','actual.csv':'independent bytes',
                              'simulation.stage.json':'{"state":"COMPLETED"}',
                              'verification.json':'{"difference_count":0}','diffs.json':'[]'}.items():
                (out/name).write_text(text)
            run={'scenario':'fixed-profile','started_utc':'2026-11-02T00:00:00Z',
                 'source_snapshot':'/frozen/source',
                 'source_sha256':{'rtl/fixed.sv':'source'},'input_sha256':{'input.json':sha(out/'input.json')},
                 'build_receipt_sha256':'native','stages':{'simulation':{'cwd':'/original/attempt'},
                    'verification':{'started_utc':'2026-11-02T00:00:01Z','finished_utc':'2026-11-02T00:00:02Z',
                    'command':['python3','/frozen/source/tests/scale/bounded.py','worker','topology_revised','fixed-profile','qualify','/original/attempt']}},
                 'evidence_sha256':{p.name:sha(p) for p in out.iterdir()}}
            run['verification']={'difference_count':0}
            proof={'schema':'bw-source-bound-verification-v1','source_sha256':run['source_sha256'],
                   'input_sha256':run['input_sha256'],'regenerated_inputs_sha256':run['input_sha256'],
                   'build_receipt_sha256':'native','scenario':'fixed-profile',
                   'started_utc':run['started_utc'],'attempt_directory':'/original/attempt',
                   'simulation_stage_sha256':sha(out/'simulation.stage.json'),
                   'consumed_sha256':{n:d for n,d in run['evidence_sha256'].items()
                                     if n not in ('verification.json','diffs.json')},
                   'verification_sha256':sha(out/'verification.json'),'diffs_sha256':sha(out/'diffs.json')}
            proof.update(audit_started_utc='2026-11-02T00:00:01.100000Z',
                         audit_finished_utc='2026-11-02T00:00:01.900000Z',elapsed_seconds=0.8)
            (out/'qualification.json').write_text(json.dumps(proof))
            run['qualification_sha256']=sha(out/'qualification.json')
            validate_source_bound_verification(run,out)
            changed_summary=copy.deepcopy(run);changed_summary['verification']['checked_raw']=123
            with self.assertRaisesRegex(ValueError,'summary'):
                validate_source_bound_verification(changed_summary,out)
            wrong=copy.deepcopy(run);wrong['started_utc']='2026-11-02T01:00:00Z'
            with self.assertRaisesRegex(ValueError,'attempt'):
                validate_source_bound_verification(wrong,out)
            (out/'actual.csv').write_text('changed raw bytes')
            # Even a newly written outer hash cannot detach the old audit
            # receipt from the raw stream it actually checked.
            run['evidence_sha256']['actual.csv']=sha(out/'actual.csv')
            with self.assertRaisesRegex(ValueError,'consumed'):
                validate_source_bound_verification(run,out)

    def test_full_audit_covers_every_executed_profile_in_order(self):
        from revised_suite import profiles
        self.assertEqual(FULL, profiles('full'))
        self.assertTrue({'history-revised-ns-reset', 'history-revised-cycle-reset',
                         'history-revised-ns-overrun'} <= set(FULL))

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
        with self.assertRaisesRegex(ValueError,'interval|duration'):
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

    def test_parent_run_cannot_hide_executed_stage_time_as_suite_overhead(self):
        value,runs=bound_metadata();run=runs[FULL[0]]
        run.update(elapsed_seconds=.001,finished_utc='2026-10-26T00:00:00.001000Z')
        value['orchestration_seconds']+=.999
        with self.assertRaises(ValueError):
            validate_suite(value,run_loader=lambda row:runs[row['name']])

    def test_recorded_real_run_rejects_underreported_parent_and_failed_children(self):
        original=json.loads((Path(__file__).with_name('run-time-fixture.json')).read_text())['run']
        validate_run_metadata(original)
        changed=copy.deepcopy(original)
        changed['elapsed_seconds']=.001
        changed['finished_utc']=datetime.datetime.utcfromtimestamp(utc_seconds(changed['started_utc'])+.001).isoformat()+'Z'
        with self.assertRaises(ValueError):validate_run_metadata(changed)
        changed=copy.deepcopy(original);changed['stages']['simulation']['returncode']=7
        with self.assertRaisesRegex(ValueError,'failed'):validate_run_metadata(changed)
        changed=copy.deepcopy(original);compiled=changed['stages']['compile'];changed['compile_reused']=True
        changed['stages']['compile']=dict(state='CACHED',elapsed_seconds=0,original=compiled)
        with self.assertRaisesRegex(ValueError,'prior'):validate_run_metadata(changed)
        for key in ('started_utc','finished_utc'):
            compiled[key]=datetime.datetime.utcfromtimestamp(utc_seconds(compiled[key])-1000).isoformat()+'Z'
        validate_run_metadata(changed)


if __name__=='__main__':
    unittest.main()
