"""Native Flutter instrumentation, migration and real Android OS tests."""
import os
import subprocess
import xml.etree.ElementTree as ET
from device_test_runner import ROOT, run

ARTIFACTS = ROOT / 'e2e/artifacts/flutter-integration'
APP = ROOT / 'flutter_app'
serial = os.environ.get('ANDROID_SERIAL', 'emulator-5554')
# Gradle connected tests target every attached device. Refuse physical devices
# before building/installing, in addition to the Dart/native safety guards.
devices = subprocess.check_output(['adb', 'devices'], text=True).splitlines()[1:]
attached = [line.split()[0] for line in devices if line.strip()]
if attached != [serial] or not serial.startswith('emulator-'):
    raise SystemExit('Exactly one disposable Android emulator is required')
try:
    run(['flutter', 'build', 'apk', '--debug', '--flavor', 'e2e',
         '--target', 'integration_test/app_test.dart'], cwd=APP,
        log=ARTIFACTS / 'build.log')
    run(['./gradlew', '--no-daemon', 'app:connectedE2eDebugAndroidTest',
         '-Ptarget=' + str(APP / 'integration_test/app_test.dart')],
        cwd=APP / 'android', timeout=900, log=ARTIFACTS / 'instrumentation.log')
    reports = list((APP / 'build/app/outputs/androidTest-results/connected').rglob('TEST-*.xml'))
    cases = [case for report in reports for case in ET.parse(report).iter('testcase')]
    if len(cases) < 3 or any(case.find(tag) is not None for case in cases for tag in ('failure', 'error', 'skipped')):
        raise RuntimeError('Expected at least three passing Dart scenarios without skips/failures')
    run(['python3', 'scripts/build_flutter.py', 'apk', '--edition', 'e2e', '--debug'],
        log=ARTIFACTS / 'app-build.log')
    run(['python3', 'flutter_app/e2e/android_smoke.py'], timeout=1200,
        log=ARTIFACTS / 'os-smoke.log')
    run(['python3', 'flutter_app/e2e/android_network.py'], timeout=600,
        log=ARTIFACTS / 'network.log')
    run(['./gradlew', '--no-daemon', 'lintE2eDebug'], cwd=APP / 'android',
        log=ARTIFACTS / 'lint.log')
finally:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    with (ARTIFACTS / 'logcat.txt').open('w') as output:
        subprocess.run(['adb', '-s', serial, 'logcat', '-d'], stdout=output,
                       stderr=subprocess.STDOUT, timeout=30)
