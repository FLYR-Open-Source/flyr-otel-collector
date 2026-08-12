#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT_DIR=.smoke-test-output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
chmod 777 "$OUTPUT_DIR"

export OTEL_VERSION
OTEL_VERSION=$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' builder-config.yaml | head -n 1)

export COLLECTOR_IMAGE="${COLLECTOR_IMAGE:-flyr-otel-collector:dev}"

COMPOSE=(docker compose -f docker-compose.smoke-test.yaml -p otel-smoke-test)

cleanup() {
  "${COMPOSE[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup

if docker image inspect "$COLLECTOR_IMAGE" >/dev/null 2>&1; then
  echo "Using existing image $COLLECTOR_IMAGE"
else
  echo "Building image $COLLECTOR_IMAGE"
  "${COMPOSE[@]}" build collector
fi

echo "Starting collector (otel version: $OTEL_VERSION)"
"${COMPOSE[@]}" up -d collector
sleep 3
"${COMPOSE[@]}" ps collector | grep -q "Up" || { echo "ERROR: collector is not running"; exit 1; }

echo "Sending test traces and logs"
"${COMPOSE[@]}" run --rm telemetrygen-traces
"${COMPOSE[@]}" run --rm telemetrygen-logs

echo "Verifying ddtags in traces output"
sleep 2
TRACES_FILE="$OUTPUT_DIR/traces.json"
[ -s "$TRACES_FILE" ] || { echo "ERROR: $TRACES_FILE is missing or empty"; exit 1; }
jq -es '
  [.[].resourceSpans[].scopeSpans[].spans[].attributes[]? | select(.key == "ddtags")] | length > 0
' "$TRACES_FILE" >/dev/null || { echo "ERROR: ddtags attribute not found in traces output"; exit 1; }

echo "Verifying ddtags in logs output"
LOGS_FILE="$OUTPUT_DIR/logs.json"
[ -s "$LOGS_FILE" ] || { echo "ERROR: $LOGS_FILE is missing or empty"; exit 1; }
jq -es '
  [.[].resourceLogs[].scopeLogs[].logRecords[].attributes[]? | select(.key == "ddtags")] | length > 0
' "$LOGS_FILE" >/dev/null || { echo "ERROR: ddtags attribute not found in logs output"; exit 1; }

echo "Smoke test passed"
