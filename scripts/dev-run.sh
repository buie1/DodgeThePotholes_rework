#!/usr/bin/env bash
# Runs the game in the iOS simulator in a dev scenario, takes screenshots during the
# run and copies out the event log. Debug builds only; see docs/DEV_MODE.md.
#
# Usage: scripts/dev-run.sh <preset | '{json}'> [seconds] [--shots N] [--autopilot] [--no-build]
#   preset       a DevScenario preset name, e.g. monsterTruck, or inline scenario JSON
#   seconds      how long to let the run play (default 15)
#   --shots N    screenshots spread over the run (default 3)
#   --autopilot  let the bot drive
#   --no-build   reuse the last build
#
# Output: build/dev-runs/<timestamp>-<name>/ with shot-N.png, devlog.jsonl and run.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.jonbuie.dodgethepotholes.app"
DEVICE_NAME="iPhone 17"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/DodgeThePotholes.app"

scenario="${1:?usage: scripts/dev-run.sh <preset | '{json}'> [seconds] [--shots N] [--autopilot] [--no-build]}"
shift
seconds=15
shots=3
autopilot=false
build=true
while (($#)); do
  case "$1" in
    --shots) shots="$2"; shift ;;
    --autopilot) autopilot=true ;;
    --no-build) build=false ;;
    *) seconds="$1" ;;
  esac
  shift
done

# Simulator: use the booted one, or boot the default device.
udid="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
if [[ -z "$udid" ]]; then
  udid="$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | grep -Eo '[0-9A-F-]{36}' | head -1)"
  echo "Booting $DEVICE_NAME ($udid)..."
  xcrun simctl boot "$udid"
fi

if $build; then
  echo "Building..."
  xcodebuild -scheme DodgeThePotholes -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$DERIVED" build -quiet
fi
xcrun simctl install "$udid" "$APP"
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true

if [[ "$scenario" == \{* ]]; then
  args=(-devScenarioJSON "$scenario"); name="custom"
else
  args=(-devScenario "$scenario"); name="$scenario"
fi
$autopilot && args+=(-devAutopilot)

out="$ROOT/build/dev-runs/$(date +%Y%m%d-%H%M%S)-$name"
mkdir -p "$out"
printf 'scenario: %s\nseconds: %s\nautopilot: %s\nargs: %s\n' "$scenario" "$seconds" "$autopilot" "${args[*]}" > "$out/run.txt"

echo "Launching $name for ${seconds}s..."
xcrun simctl launch "$udid" "$BUNDLE_ID" "${args[@]}" > /dev/null

interval="$(echo "scale=2; $seconds / $shots" | bc)"
for ((i = 1; i <= shots; i++)); do
  sleep "$interval"
  xcrun simctl io "$udid" screenshot "$out/shot-$i.png" > /dev/null 2>&1
done

container="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)"
cp "$container/Documents/devlog.jsonl" "$out/devlog.jsonl"
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true

echo "Output: $out"
echo "Events: $(grep -c . "$out/devlog.jsonl") lines; last snapshot:"
grep '"snapshot"' "$out/devlog.jsonl" | tail -1 || echo "(none)"
grep '"gameOver"' "$out/devlog.jsonl" || true
