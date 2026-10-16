#!/usr/bin/env bash
# Sends 10 requests to the Service and prints which version answered
P=$(kubectl -n bluegreen get svc bluegreen-svc -o jsonpath='{.spec.ports[0].nodePort}')
for i in $(seq 1 10); do
  curl -s --max-time 3 http://localhost:$P/ | grep -o '"version":"[a-z]*"' || echo "no-response"
done | sort | uniq -c
