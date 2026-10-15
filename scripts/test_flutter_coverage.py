import importlib.util
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('gate',Path(__file__).with_name('check_flutter_coverage.py'))
gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
class CoverageGateTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.previous=gate.ROOT;gate.ROOT=self.root
        self.addCleanup(setattr,gate,'ROOT',self.previous)
        (self.root/'lib/domain').mkdir(parents=True);(self.root/'lib/domain/rules.dart').write_text('rules')
        self.report=self.root/'coverage.info'
    def report_text(self,lines=9,branches=4):
        return 'SF:lib/domain/rules.dart\n'+''.join(f'DA:{i+1},{int(i<lines)}\n' for i in range(10))+''.join(f'BRDA:1,0,{i},{int(i<branches)}\n' for i in range(5))+'end_of_record\n'
    def test_thresholds_and_missing_data_fail_closed(self):
        for text in ['',self.report_text(8,5),self.report_text(10,3),self.report_text().split('BRDA:')[0]]:
            self.report.write_text(text)
            with self.assertRaises(ValueError):gate.verify(self.report)
        self.report.write_text(self.report_text());gate.verify(self.report)
    def test_new_logic_files_are_automatically_required(self):
        (self.root/'lib/new_helper.dart').write_text('new')
        self.report.write_text(self.report_text())
        with self.assertRaisesRegex(ValueError,'new_helper.dart: missing coverage'):gate.verify(self.report)
if __name__=='__main__':unittest.main()
