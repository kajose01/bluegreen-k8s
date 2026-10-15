#!/usr/bin/env bash
# Sends 10 requests to the Service and prints the version that answered
for i in $(seq 1 10); do curl -s --max-time 3 http://localhost:30090/ ; done | sort | uniq -c
