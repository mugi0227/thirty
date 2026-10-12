#!/bin/bash
# usage: boot_sim.sh "<device name>"  → prints the UDID, boots it, and cleans the status bar.
set -euo pipefail
NAME="$1"
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
found = sorted((runtime, d["udid"]) for runtime, items in devices.items() if "iOS" in runtime for d in items if d["name"] == name)
if not found:
    sys.exit("no simulator named " + name)
print(found[-1][1])' "$NAME")
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
echo "$UDID"
