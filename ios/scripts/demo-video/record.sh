#!/bin/bash
# Neemt het scherm van een simulator op terwijl een UI-testscheme draait (test-without-building).
# De opname wordt ook bij een mislukte test netjes afgesloten, zodat de video bruikbaar is.
#
# Gebruik: record.sh <naam> <scheme> <platform> <udid> <procesnaam>   (vanuit ios/, met OUT gezet)
#
# Met DEMO_LOCATION_ROUTE (coördinaten "lat,lon lat,lon ...") loopt de simulator dat pad af zodra
# de test meldt dat de opname van de workout begonnen is.
#
# Met DEMO_DIAGNOSE=1 komt er extra materiaal om haperingen te onderzoeken: van de iPhone-app een
# `sample`-rapport over de hele test (waar de main thread tijd aan besteedt) en het logboek van
# locationd, van de Watch elke 2 s een schermafbeelding. Dat vertraagt de app iets; gebruik het
# niet voor de uiteindelijke video.
set -u
NAME="$1"; SCHEME="$2"; PLATFORM="$3"; UDID="$4"; PROCESS="$5"
LOGS="$OUT/logs"
VIDEO="$OUT/$NAME-raw.mp4"
TESTLOG="$LOGS/$NAME-test.log"
RESULT="${RUNNER_TEMP:-/tmp}/$NAME.xcresult"
TIMEOUT="${TEST_TIMEOUT:-540}"
mkdir -p "$LOGS"
rm -rf "$RESULT"

xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$VIDEO" > "$LOGS/$NAME-record.log" 2>&1 &
REC=$!
for _ in $(seq 1 40); do
  grep -q "Recording started" "$LOGS/$NAME-record.log" && break
  sleep 0.5
done
date +%s > "$OUT/$NAME-recording-start.txt"

# Het logboek van de app zelf (meldingen van UIKit, SwiftUI, CoreLocation enz.).
xcrun simctl spawn "$UDID" log stream --style compact --level default \
  --predicate "process == \"$PROCESS\"" > "$LOGS/$NAME-app.log" 2>&1 &
APPLOG=$!

# De test geeft met een signaalbestand aan dat de opname van de workout loopt; laat de simulator
# dan het pad uit DEMO_LOCATION_ROUTE aflopen (4,2 m/s, elke seconde een positie). Niet fataal.
SIGNALS="${RUNNER_TEMP:-/tmp}/demo-signals"
mkdir -p "$SIGNALS"
rm -f "$SIGNALS"/*
if [ -n "${DEMO_LOCATION_ROUTE:-}" ]; then
  (
    for _ in $(seq 1 3000); do
      if [ -e "$SIGNALS/location-scenario" ]; then
        date +%H:%M:%S
        # shellcheck disable=SC2086
        xcrun simctl location "$UDID" start --speed=4.2 --interval=1 $DEMO_LOCATION_ROUTE
        break
      fi
      sleep 0.2
    done
  ) > "$LOGS/$NAME-location-scenario.log" 2>&1 &
fi

TEST_RUNNER_DEMO_SIGNAL_DIR="$SIGNALS" xcodebuild test-without-building \
  -project Metric.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=$PLATFORM,id=$UDID" \
  -derivedDataPath DerivedData \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RESULT" \
  > "$TESTLOG" 2>&1 &
XB=$!
# Waakhond: breek een vastgelopen test af, zodat de opname nog kan worden afgesloten.
( sleep "$TIMEOUT" && echo "WATCHDOG: test afgebroken na $TIMEOUT s" >> "$TESTLOG" && kill -TERM "$XB" ) > /dev/null 2>&1 &
WD=$!

if [ "${DEMO_DIAGNOSE:-0}" = "1" ] && [ "$PLATFORM" = "watchOS Simulator" ]; then
  mkdir -p "$OUT/$NAME-shots"
  (
    while kill -0 "$XB" 2> /dev/null; do
      xcrun simctl io "$UDID" screenshot --type=jpeg "$OUT/$NAME-shots/$(date +%H%M%S).jpg" > /dev/null 2>&1
      sleep 2
    done
  ) > /dev/null 2>&1 &
fi
if [ "${DEMO_DIAGNOSE:-0}" = "1" ] && [ "$PLATFORM" = "iOS Simulator" ]; then
  mkdir -p "$OUT/$NAME-samples"
  # Eén rapport over de hele test: wacht tot de app draait en bemonster hem dan tot hij stopt.
  (
    while kill -0 "$XB" 2> /dev/null; do
      PID=$(pgrep -x "$PROCESS" | head -n 1)
      if [ -n "$PID" ]; then
        sample "$PID" "$TIMEOUT" 10 -mayDie -file "$OUT/$NAME-samples/$(date +%H%M%S).txt"
      fi
      sleep 1
    done
  ) > "$LOGS/$NAME-sample.log" 2>&1 &
  # Wat locationd met de gesimuleerde posities doet.
  xcrun simctl spawn "$UDID" log stream --style compact --level default \
    --predicate 'process == "locationd"' > "$LOGS/$NAME-locationd.log" 2>&1 &
  LOCLOG=$!
fi

wait "$XB"
STATUS=$?
pkill -P "$WD" > /dev/null 2>&1
kill "$WD" > /dev/null 2>&1
kill "$APPLOG" ${LOCLOG:-} > /dev/null 2>&1

sleep 1
xcrun simctl io "$UDID" screenshot "$OUT/$NAME-end.png" > /dev/null 2>&1 || true

kill -INT "$REC"
for _ in $(seq 1 80); do
  kill -0 "$REC" 2> /dev/null || break
  sleep 0.5
done
if kill -0 "$REC" 2> /dev/null; then
  echo "De opname stopt niet na SIGINT; SIGTERM."
  kill -TERM "$REC"
  sleep 2
fi
ls -l "$VIDEO" || true

grep "DEMO-MARK" "$TESTLOG" > "$OUT/$NAME-marks.txt" || true
sed -n '/DEMO-HIERARCHY-BEGIN/,/DEMO-HIERARCHY-END/p' "$TESTLOG" > "$OUT/$NAME-hierarchy.txt"
[ -s "$OUT/$NAME-hierarchy.txt" ] || rm -f "$OUT/$NAME-hierarchy.txt"
if [ "$STATUS" -ne 0 ]; then
  # Schermafbeeldingen die de test bij een fout als bijlage bewaart.
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/$NAME-attachments" > /dev/null 2>&1 || true
fi

{
  echo "== $NAME: test, exit $STATUS"
  grep -E "(Test Case .*(passed|failed)|error:|XCTAssert|Assertion Failure|Failed to|Testing failed|TEST EXECUTE (SUCCEEDED|FAILED)|Executed [0-9]+ test|WATCHDOG|Unable to find a destination|Terminating app due to|Crash)" "$TESTLOG" \
    | awk '!seen[$0]++' | head -n 60
  echo "-- markeringen"
  sed -E 's/ epoch=.*//' "$OUT/$NAME-marks.txt" 2> /dev/null | tr '\n' ';'
  echo
} | tee "$OUT/$NAME-test-summary.txt"
if [ "$STATUS" -ne 0 ]; then
  echo "-- laatste regels van het testlog"
  sed '/DEMO-HIERARCHY-BEGIN/,/DEMO-HIERARCHY-END/d' "$TESTLOG" | tail -n 30
fi
exit "$STATUS"
