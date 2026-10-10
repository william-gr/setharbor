"""Package a dated main APK with its exact Git provenance; standard library only."""
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess


def package():
    if subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip():
        raise ValueError('APK provenance requires a clean Git checkout')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    date = subprocess.check_output(['git', 'log', '-1', '--format=%cs'], text=True).strip().replace('-', '')
    # Reject drift between the workflow's source step and the actual checkout.
    if os.environ.get('APP_VERSION', date) != date or not commit.startswith(os.environ.get('SOURCE_SHA', commit)):
        raise ValueError('APK source metadata does not match the checkout')
    apk = Path('app/build/outputs/apk/debug/app-debug.apk')
    metadata = json.loads(apk.with_name('output-metadata.json').read_text())
    if metadata['applicationId'] != 'com.william.treino':
        raise ValueError('Only the regular application APK may be packaged')
    outputs = metadata['elements']
    if len(outputs) != 1 or outputs[0]['versionName'] != date or outputs[0]['versionCode'] != int(date):
        raise ValueError('APK version does not match the source commit date')
    output = Path('dist')
    output.mkdir(exist_ok=True)
    name = f'SetHarbor-{date}-{commit[:12]}.apk'
    shutil.copy2(apk, output / name)
    checksum = hashlib.sha256(apk.read_bytes()).hexdigest()
    (output / 'SHA256SUMS').write_text(f'{checksum}  {name}\n')
    (output / 'build-info.json').write_text(json.dumps({
        'branch': 'main', 'commit': commit, 'versionName': date,
        'versionCode': int(date), 'apk': name, 'buildType': 'debug', 'sha256': checksum,
    }, indent=2) + '\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
            summary.write(f'### SetHarbor {date}\n\nSource: `{commit}`\n\nDownload `{name}` from this run’s APK artifact.\n')
    return output / name


if __name__ == '__main__':
    print(package())
