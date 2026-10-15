"""Select an existing available iPhone simulator for CI; never a physical device."""
import json
import subprocess

data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j'],text=True))
devices=[device for runtime,entries in data['devices'].items() if '.iOS-' in runtime for device in entries if device['name'].startswith('iPhone') and device.get('isAvailable')]
if not devices:raise RuntimeError('No available iPhone simulator runtime installed')
device=devices[0]
if device['state']!='Booted':subprocess.run(['xcrun','simctl','boot',device['udid']],check=True)
subprocess.run(['xcrun','simctl','bootstatus',device['udid'],'-b'],check=True,stdout=subprocess.DEVNULL)
print('device='+device['udid'])
