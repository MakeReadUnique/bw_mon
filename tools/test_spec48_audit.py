import unittest
import tempfile
import json
import hashlib
from unittest.mock import patch
from pathlib import Path

from spec48_audit import case_inventory,contract_fingerprint,verify
from contract_campaign import partition


class CompleteContractInventory(unittest.TestCase):
    def test_real_contract_names_can_contain_a_hyphen(self):
        cases=[{'name':'storage_failure_report_cfg-line'}]
        output='PASS storage_failure_report_cfg-line: raw.log\n1/1 contract cases passed\n'
        self.assertEqual(case_inventory(cases,output),['storage_failure_report_cfg-line'])

    def test_delivery_rejects_outer_budget_overrun_or_incomplete_execution(self):
        names=['quick-cold','quick-hot','full-cold','full-hot','campaign58','acceptance',
               'bw_mon_quickstart-compile','bw_mon_quickstart','bw_mon_grouped-compile',
               'bw_mon_grouped','verdi-applicability','python-tools','contracts-final']
        budgets={'quick-cold':300,'quick-hot':120,'full-cold':1800,'full-hot':1800,'campaign58':900}
        rows=[dict(name=name,exit_code=0,elapsed_seconds=10,
                   **(dict(budget_seconds=budgets[name],budget_met=True) if name in budgets else {}))
              for name in names]
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            receipt=dict(schema='bw-spec48-run-evidence-v1',state='VERIFIED',files_sha256={},
                         source_head='fixed',execution=rows)
            original=root/'execution/results.json';original.parent.mkdir();original.write_text(json.dumps(rows))
            receipt['files_sha256']={'execution/results.json':hashlib.sha256(original.read_bytes()).hexdigest()}
            path=root/'run-evidence.json'
            with patch('spec48_audit.verify_contracts',return_value=597),patch('spec48_audit.subprocess.check_call'):
                path.write_text(json.dumps(receipt));self.assertTrue(verify(root)['checked_pass'])
                for altered in [rows[:-1],rows+[rows[0]],
                                [dict(r,elapsed_seconds=1800.001) if r['name']=='full-cold' else r for r in rows],
                                [dict(r,exit_code=1) if r['name']=='contracts-final' else r for r in rows],
                                [dict(r,elapsed_seconds=11) if r['name']=='full-cold' else r for r in rows]]:
                    receipt['execution']=altered;path.write_text(json.dumps(receipt))
                    with self.assertRaises(ValueError):verify(root)

    def test_parallel_contracts_share_no_test_top_and_cover_each_case_once(self):
        cases=[{'name':'a0','top':'a'},{'name':'a1','top':'a','defines':['FAULT']},
               {'name':'b','top':'b'},{'name':'c','top':'c'}]
        groups=partition(cases,3)
        names=[case['name'] for group in groups for case in group]
        self.assertEqual(sorted(names),['a0','a1','b','c'])
        self.assertEqual(len(names),len(set(names)))
        owners={}
        for n,group in enumerate(groups):
            for case in group:
                self.assertTrue(case['top'] not in owners or owners[case['top']]==n)
                owners[case['top']]=n

    def test_compiled_receipt_changes_with_consumed_source_and_macro_variant(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'rtl').mkdir();(root/'tests').mkdir()
            (root/'rtl/bw_mon_pkg.sv').write_text('package p; endpackage\n')
            (root/'tests/run.py').write_text('fixed driver\n')
            source=root/'tests/tb_public.sv';source.write_text('module tb_public; endmodule\n')
            case={'top':'tb_public'}
            before=contract_fingerprint(root,'/measured/source',case)
            self.assertNotEqual(before,contract_fingerprint(root,'/measured/source',dict(case,defines=['FAULT'])))
            source.write_text('module tb_public; initial $fatal; endmodule\n')
            self.assertNotEqual(before,contract_fingerprint(root,'/measured/source',case))

    def test_every_declared_case_must_pass_exactly_once(self):
        cases=[{'name':'healthy'},{'name':'expected_warning'}]
        output='PASS healthy: log\nPASS expected_warning: log\n2/2 contract cases passed\n'
        self.assertEqual(case_inventory(cases,output),['healthy','expected_warning'])
        for changed in [output.replace('PASS healthy','FAIL healthy'),
                        output.replace('expected_warning:','healthy:'),
                        output.replace('PASS expected_warning: log\n',''),
                        output.replace('2/2','1/2')]:
            with self.assertRaises(ValueError):case_inventory(cases,changed)


if __name__=='__main__':unittest.main()
