#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Anchoring to both the collector core module path and the v0.x (beta) train keeps
# this from matching contrib modules, datadogtagsprocessor, or dist.version.
# `|| true` so a no-match grep reports the error below instead of dying under pipefail.
VERSIONS=$(grep -oE 'go\.opentelemetry\.io/collector/[A-Za-z0-9/_-]+ v0\.[0-9]+\.[0-9]+' builder-config.yaml \
  | awk '{print $2}' | sort -u || true)

COUNT=$(printf '%s' "$VERSIONS" | grep -c . || true)
if [ "$COUNT" -ne 1 ]; then
  echo "ERROR: expected exactly 1 go.opentelemetry.io/collector v0.x version in builder-config.yaml, found $COUNT:" >&2
  printf '%s\n' "$VERSIONS" >&2
  exit 1
fi

printf '%s\n' "$VERSIONS"
