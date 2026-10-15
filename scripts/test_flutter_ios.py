"""Run shared Dart tests in a hosted XCTest, without VM-service discovery."""
import argparse
import json
import subprocess
import time
from device_test_runner import ROOT, run

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
args = parser.parse_args()
APP = ROOT / 'flutter_app'
ARTIFACTS = ROOT / 'e2e/artifacts/flutter-ios-integration'


def bundle(name):
    path = ARTIFACTS / (name + '.xcresult')
    if path.exists():
        path.rename(ARTIFACTS / (name + '-' + str(time.time_ns()) + '.xcresult'))
    return path


def verify_results(name, expected):
    result = json.loads(subprocess.check_output(
        ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path',
         str(ARTIFACTS / (name + '.xcresult')), '--format', 'json'],
        text=True, timeout=30))
    (ARTIFACTS / (name + '-summary.json')).write_text(json.dumps(result, indent=2))
    if (result.get('passedTests') != expected or result.get('failedTests') != 0
            or result.get('skippedTests') != 0 or result.get('expectedFailures') != 0):
        raise RuntimeError(f'Expected {expected} passing XCTest cases, no skips/failures: {result}')


run(['xcrun', 'simctl', 'bootstatus', args.device, '-b'],
    timeout=120, log=ARTIFACTS / 'simulator.log')
run(['flutter', 'build', 'ios', '--simulator', '--debug', '--no-codesign',
     '--target', 'integration_test/app_test.dart'], cwd=APP,
    log=ARTIFACTS / 'build.log')
run(['xcodebuild', 'test', '-workspace', 'Runner.xcworkspace', '-scheme', 'Runner',
     '-destination', 'platform=iOS Simulator,id=' + args.device,
     '-only-testing:SharedIntegrationTests', '-parallel-testing-enabled', 'NO',
     '-collect-test-diagnostics', 'never', '-maximum-test-execution-time-allowance', '180',
     '-test-timeouts-enabled', 'YES', 'CODE_SIGNING_ALLOWED=NO',
     '-resultBundlePath', str(bundle('shared'))],
    cwd=APP / 'ios', timeout=900, log=ARTIFACTS / 'xctest.log')
verify_results('shared', 1)

# Return to the production Dart entry point before exercising OS UI flows.
run(['flutter', 'build', 'ios', '--simulator', '--debug', '--no-codesign'],
    cwd=APP, log=ARTIFACTS / 'app-build.log')
run(['xcodebuild', 'test', '-workspace', 'Runner.xcworkspace', '-scheme', 'Runner',
     '-destination', 'platform=iOS Simulator,id=' + args.device,
     '-only-testing:RunnerTests', '-parallel-testing-enabled', 'NO',
     '-collect-test-diagnostics', 'never', '-maximum-test-execution-time-allowance', '300',
     '-test-timeouts-enabled', 'YES', 'CODE_SIGNING_ALLOWED=NO',
     '-resultBundlePath', str(bundle('native'))],
    cwd=APP / 'ios', timeout=900, log=ARTIFACTS / 'native.log')
verify_results('native', 2)
