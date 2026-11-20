#!/usr/bin/env bash
# Usage: ./scripts/switch.sh blue|green
# Switches the Service to the target only if it is fully ready, verifies real
# HTTP responses afterwards, and rolls back automatically if verification fails.
set -euo pipefail
NS=bluegreen
TARGET="${1:?usage: switch.sh blue|green}"
[[ "$TARGET" == "blue" || "$TARGET" == "green" ]] || { echo "must be blue or green"; exit 1; }
TIMEOUT="${TIMEOUT:-120s}"
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/../evidence"
LOG="$DIR/../evidence/release.log"
log() { echo "$(date +%T) $*" | tee -a "$LOG"; }

set_selector() {
  kubectl -n "$NS" patch svc bluegreen-svc -p \
    "{\"spec\":{\"selector\":{\"app\":\"bluegreen-demo\",\"version\":\"$1\"}}}" >/dev/null
}
verify() {   # wait up to ~30s for 10/10 responses from version $1
  for _ in $(seq 1 15); do
    "$DIR/check.sh" "$1" 10 >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

PREV=$(kubectl -n "$NS" get svc bluegreen-svc -o jsonpath='{.spec.selector.version}')
log "release start: target=$TARGET previous=$PREV"

if ! kubectl -n "$NS" rollout status "deploy/app-$TARGET" --timeout="$TIMEOUT"; then
  log "REJECTED: app-$TARGET did not become ready; traffic stays on $PREV"
  exit 1
fi
DESIRED=$(kubectl -n "$NS" get deploy "app-$TARGET" -o jsonpath='{.spec.replicas}')
READY=$(kubectl -n "$NS" get deploy "app-$TARGET" -o jsonpath='{.status.readyReplicas}')
if [[ "${READY:-0}" != "$DESIRED" ]]; then
  log "REJECTED: only ${READY:-0}/$DESIRED replicas ready; traffic stays on $PREV"
  exit 1
fi

set_selector "$TARGET"
if verify "$TARGET"; then
  log "SUCCESS: traffic now goes to $TARGET (10/10 verified responses)"
else
  log "VALIDATION FAILED: $TARGET did not answer correctly; rolling back to $PREV"
  set_selector "$PREV"
  if verify "$PREV"; then log "ROLLBACK OK: traffic back on $PREV"; else log "ROLLBACK FAILED: check manually"; fi
  exit 1
fi
