"""Boot once; each UI test supplies its own app language, without changing SpringBoard."""
import json
import subprocess
import sys

name = sys.argv[1]
runtime_preference = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
matches = sorted((runtime, device['udid']) for runtime, items in devices.items() if 'iOS' in runtime
                 for device in items if device['name'] == name)
if matches:
    runtime, udid = next((item for item in matches if item[0] == runtime_preference), matches[-1])
else:
    types = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devicetypes', '-j']))['devicetypes']
    kind = next(t['identifier'] for t in types if t['name'] == name)
    runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
    ios = [r for r in runtimes if r.get('platform') == 'iOS' and r.get('isAvailable')]
    fits = [r for r in ios if any(t.get('identifier') == kind for t in r.get('supportedDeviceTypes', []))]
    runtime = (fits or ios)[-1]['identifier']
    udid = subprocess.check_output(['xcrun', 'simctl', 'create', name, kind, runtime], text=True).strip()
print(f'Booting {name} on {runtime}', file=sys.stderr, flush=True)
subprocess.run(['xcrun', 'simctl', 'boot', udid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True, timeout=300, stdout=sys.stderr)
subprocess.run(['xcrun', 'simctl', 'ui', udid, 'appearance', 'light'], check=True)
subprocess.run(['xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100'])
print(udid)
