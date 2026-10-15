"""Select and boot an available iPhone simulator, with bounded diagnostics."""
import json
import subprocess
import sys

try:
    print('Querying available iPhone simulators', file=sys.stderr, flush=True)
    data = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], text=True, timeout=600))
    devices = [device for runtime, entries in data['devices'].items()
               if '.iOS-' in runtime for device in entries
               if device['name'].startswith('iPhone') and device.get('isAvailable')]
    if not devices:
        raise RuntimeError('No available iPhone simulator runtime installed')
    device = next((entry for entry in devices if entry['state'] == 'Booted'), devices[0])
    print(f"Booting {device['name']} ({device['udid']})", file=sys.stderr, flush=True)
    if device['state'] != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True,
                       stdout=sys.stderr, timeout=600)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'],
                   check=True, stdout=sys.stderr, timeout=600)
except (subprocess.SubprocessError, RuntimeError):
    subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'available'],
                   stdout=sys.stderr, stderr=sys.stderr, timeout=30)
    raise
# stdout is appended to GITHUB_OUTPUT; diagnostics must stay on stderr.
print('device=' + device['udid'])
