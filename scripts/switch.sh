#!/usr/bin/env bash
# Usage: ./scripts/switch.sh blue|green
set -euo pipefail
TARGET="${1:?usage: switch.sh blue|green}"
[[ "$TARGET" == "blue" || "$TARGET" == "green" ]] || { echo "must be blue or green"; exit 1; }
kubectl -n bluegreen rollout status deploy/app-$TARGET --timeout=120s
kubectl -n bluegreen patch svc bluegreen-svc -p "{\"spec\":{\"selector\":{\"app\":\"bluegreen-demo\",\"version\":\"$TARGET\"}}}"
echo "$(date +%T) traffic now goes to: $(kubectl -n bluegreen get svc bluegreen-svc -o jsonpath='{.spec.selector.version}')"
