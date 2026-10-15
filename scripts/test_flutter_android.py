"""Run Flutter device tests and migration on the disposable Android emulator."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
subprocess.run(['flutter','test','integration_test/app_test.dart','-d','emulator-5554','--flavor','e2e','--no-uninstall','--reporter','expanded'],cwd=ROOT/'flutter_app',check=True)
subprocess.run(['python3','scripts/build_flutter.py','apk','--edition','e2e','--debug'],cwd=ROOT,check=True)
subprocess.run(['python3','flutter_app/e2e/android_smoke.py'],cwd=ROOT,check=True)
subprocess.run(['python3','flutter_app/e2e/android_network.py'],cwd=ROOT,check=True)
subprocess.run(['./gradlew','--no-daemon','lintE2eDebug'],cwd=ROOT/'flutter_app/android',check=True)
