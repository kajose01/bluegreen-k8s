#!/usr/bin/env bash
# Usage: ./scripts/check.sh [expected-version] [requests]
# With an expected version: passes only if every response came from it.
# Without one: passes only if every request got a version back.
EXPECTED="${1:-}"
N="${2:-10}"
P=$(kubectl -n bluegreen get svc bluegreen-svc -o jsonpath='{.spec.ports[0].nodePort}')
declare -A seen
bad=0
for i in $(seq 1 "$N"); do
  v=$(curl -s --max-time 3 "http://localhost:$P/" | grep -o '"version":"[a-z]*"' | cut -d'"' -f4 || true)
  v="${v:-no-response}"
  seen[$v]=$(( ${seen[$v]:-0} + 1 ))
  if [[ -n "$EXPECTED" ]]; then
    [[ "$v" == "$EXPECTED" ]] || bad=$((bad+1))
  else
    [[ "$v" != "no-response" ]] || bad=$((bad+1))
  fi
done
for k in "${!seen[@]}"; do printf '%7s %s\n' "${seen[$k]}" "$k"; done | sort -k2
if [[ $bad -eq 0 ]]; then
  echo "RESULT: PASS ($N/$N responses${EXPECTED:+ from $EXPECTED})"
else
  echo "RESULT: FAIL ($bad of $N responses unexpected${EXPECTED:+, expected $EXPECTED})"
  exit 1
fi
