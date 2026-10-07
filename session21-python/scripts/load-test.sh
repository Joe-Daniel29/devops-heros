#!/usr/bin/env bash
# Generates enough concurrent API traffic to push the backend over the HPA CPU target.
#   URL=http://taskboard.local/api/tasks REQUESTS=20000 CONCURRENCY=40 ./scripts/load-test.sh
set -euo pipefail
URL="${URL:-http://taskboard.local/api/tasks}"
REQUESTS="${REQUESTS:-20000}"
CONCURRENCY="${CONCURRENCY:-40}"

echo "Load test: ${REQUESTS} requests to ${URL} with concurrency ${CONCURRENCY}"
start=$(date +%s)
seq 1 "$REQUESTS" | xargs -P "$CONCURRENCY" -I{} curl -s -o /dev/null -w '%{http_code}\n' "$URL" \
  | sort | uniq -c | awk '{printf "  HTTP %s: %s requests\n", $2, $1}'
echo "Load test completed in $(( $(date +%s) - start ))s"
