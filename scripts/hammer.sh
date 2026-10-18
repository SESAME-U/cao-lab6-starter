#!/usr/bin/env bash
# Lab 6: send one request every 0.2 s to the hello service and print who
# answered. Ctrl+C stops it and prints a summary.
#   scripts/hammer.sh          until Ctrl+C
#   scripts/hammer.sh 50       50 requests, then the summary
set -uo pipefail
url="${HELLO_URL:-http://localhost:8090/}"
max="${1:-0}"
ok=0; failed=0; n=0
summary() {
  echo
  echo "requests: $n  ok: $ok  failed: $failed"
  exit $(( failed > 0 ))
}
trap summary INT TERM
while [[ $max -eq 0 || $n -lt $max ]]; do
  n=$((n + 1))
  if out=$(curl -fsS --max-time 2 "$url" 2>&1); then
    ok=$((ok + 1)); printf '%s  %s\n' "$(date +%T)" "$out"
  else
    failed=$((failed + 1)); printf '%s  FAILED: %s\n' "$(date +%T)" "$out"
  fi
  sleep 0.2
done
summary
