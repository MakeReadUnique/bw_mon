import unittest
import tempfile
from pathlib import Path

from spec48_audit import case_inventory,contract_fingerprint


class CompleteContractInventory(unittest.TestCase):
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
