"""Run all E2E tests and write a machine-readable summary in artifacts/results.json."""
import json, os, sys, time, unittest
from pathlib import Path
here=Path(__file__).resolve().parent
sys.path.insert(0,str(here))
class ReportingResult(unittest.TextTestResult):
    def __init__(self,*args,**kwargs):super().__init__(*args,**kwargs);self.records=[];self.started={}
    def startTest(self,test):self.started[test.id()]=time.monotonic();super().startTest(test)
    def record(self,test,status,detail=''):
        self.records.append({'test':test.id(),'status':status,'seconds':round(time.monotonic()-self.started.get(test.id(),time.monotonic()),2),'detail':detail})
        output=Path(os.environ.get('E2E_ARTIFACTS',str(here/'artifacts')));output.mkdir(parents=True,exist_ok=True)
        (output/'results.json').write_text(json.dumps({'complete':False,'results':self.records},ensure_ascii=False,indent=2))
    def addSuccess(self,test):self.record(test,'passed');super().addSuccess(test)
    def addError(self,test,err):self.record(test,'error',self._exc_info_to_string(err,test));super().addError(test,err)
    def addFailure(self,test,err):self.record(test,'failed',self._exc_info_to_string(err,test));super().addFailure(test,err)
    def addSkip(self,test,reason):self.record(test,'skipped',reason);super().addSkip(test,reason)
if __name__=='__main__':
    suite=unittest.defaultTestLoader.discover(str(here),pattern='test_*.py')
    result=unittest.TextTestRunner(verbosity=2,resultclass=ReportingResult).run(suite)
    output=Path(os.environ.get('E2E_ARTIFACTS',str(here/'artifacts')));output.mkdir(parents=True,exist_ok=True)
    (output/'results.json').write_text(json.dumps({'complete':True,'tests_run':result.testsRun,'success':result.wasSuccessful(),'results':result.records},ensure_ascii=False,indent=2))
    sys.exit(0 if result.wasSuccessful() else 1)
