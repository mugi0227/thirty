#!/bin/bash
# usage: boot_sim.sh "<device name>"  → prints the UDID, boots it, and cleans the status bar.
set -euo pipefail
NAME="$1"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
found = sorted((runtime, d["udid"]) for runtime, items in devices.items() if "iOS" in runtime for d in items if d["name"] == name)
print(found[-1][1] if found else "")' "$NAME")
if [ -z "$UDID" ]; then
  # Newer device types (such as iPhone Duo) may have no simulator yet: create one.
  TYPE=$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; n=sys.argv[1]; print(next(t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if t["name"]==n))' "$NAME")
  RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["platform"]=="iOS" and x["isAvailable"]]; print(r[-1]["identifier"])')
  UDID=$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")
fi
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
echo "$UDID"
