import unittest

from compare import canonical_trace


class WaveformApplicability(unittest.TestCase):
    def test_trace_uses_signal_paths_and_physical_times_not_export_identifiers(self):
        old='''$timescale 1ps $end
$scope module scene $end
$var real 64 a bandwidth $end
$var wire 1 b full $end
$upscope $end
$enddefinitions $end
#4000
r100 a
0b
#7000
r108 a
1b
'''
        new=old.replace('1ps','1fs').replace('#4000','#4000000').replace('#7000','#7000000')
        new=new.replace('64 a bandwidth','64 xyz bandwidth').replace(' a\n',' xyz\n')
        paths=['/scene/bandwidth','/scene/full']
        expected={'/scene/bandwidth':{'kind':'real','width':64,'values':[
            [4000000,float(100).hex()],[7000000,float(108).hex()]]},
            '/scene/full':{'kind':'wire','width':1,'values':[[4000000,'0'],[7000000,'1']]}}
        self.assertEqual(canonical_trace(old,paths),expected)
        self.assertEqual(canonical_trace(new,paths),expected)
        self.assertNotEqual(canonical_trace(old.replace('r108','r107'),paths),expected)

    def test_missing_reviewed_signal_cannot_pass(self):
        text='$timescale 1fs $end\n$enddefinitions $end\n#0\n'
        with self.assertRaisesRegex(ValueError,'missing'):
            canonical_trace(text,['/scene/window_bytes'])

    def test_nonfinite_reviewed_bandwidth_cannot_certify_applicability(self):
        for value in ['nan','inf','-inf']:
            text=('$timescale 1fs $end\n$scope module scene $end\n'
                  '$var real 64 a bandwidth $end\n$upscope $end\n'
                  '$enddefinitions $end\n#0\nr'+value+' a\n')
            with self.assertRaisesRegex(ValueError,'nonfinite'):
                canonical_trace(text,['/scene/bandwidth'])

    def test_reviewed_interval_requires_initial_state_and_complete_export(self):
        text=('''$timescale 1fs $end
$scope module scene $end
$var real 64 a bandwidth $end
$upscope $end
$enddefinitions $end
#0
r100 a
#6000000
r108 a
#26000000
''')
        trace=canonical_trace(text,['/scene/bandwidth'],4000000,19000000)
        self.assertEqual(trace['/scene/bandwidth']['values'],
                         [[4000000,float(100).hex()],[6000000,float(108).hex()]])
        with self.assertRaisesRegex(ValueError,'coverage'):
            canonical_trace(text.replace('#26000000',''),['/scene/bandwidth'],4000000,19000000)
        with self.assertRaisesRegex(ValueError,'initial'):
            canonical_trace(text.replace('#0\n','#5000000\n'),['/scene/bandwidth'],4000000,19000000)

    def test_ordered_changes_at_one_physical_time_are_not_hidden(self):
        text=('''$timescale 1fs $end
$scope module scene $end
$var wire 1 a ready $end
$upscope $end
$enddefinitions $end
#0
0a
#100
1a
0a
''')
        self.assertEqual(canonical_trace(text,['/scene/ready'])['/scene/ready']['values'],
                         [[0,'0'],[100,'1'],[100,'0']])


if __name__=='__main__':
    unittest.main()
