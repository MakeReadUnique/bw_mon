import unittest
import tempfile
from pathlib import Path

from spec48_audit import case_inventory,contract_fingerprint
from contract_campaign import partition


class CompleteContractInventory(unittest.TestCase):
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
