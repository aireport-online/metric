#!/bin/bash
# Bouwt een UI-testscheme voor een simulator (build-for-testing) en vat fouten kort samen.
#
# Gebruik: build.sh <naam> <scheme> <platform> <udid>      (vanuit ios/, met OUT gezet)
set -u
NAME="$1"; SCHEME="$2"; PLATFORM="$3"; UDID="$4"
LOG="$OUT/logs/$NAME-build.log"
mkdir -p "$OUT/logs"

xcodebuild build-for-testing \
  -project Metric.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=$PLATFORM,id=$UDID" \
  -derivedDataPath DerivedData \
  > "$LOG" 2>&1
STATUS=$?

{
  echo "== $NAME: build-for-testing, exit $STATUS"
  grep -E "(error:|warning: unable|BUILD FAILED|TEST BUILD (SUCCEEDED|FAILED)|The following build commands failed|requires a development team|No profiles|Unable to find a destination|xcodebuild: error)" "$LOG" \
    | awk '!seen[$0]++' | head -n 80
} | tee "$OUT/$NAME-build-summary.txt"
if [ "$STATUS" -ne 0 ]; then
  echo "-- laatste regels van het buildlog"
  tail -n 40 "$LOG"
fi
exit "$STATUS"
