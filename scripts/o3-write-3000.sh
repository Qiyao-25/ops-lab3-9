#!/usr/bin/env bash
set -euo pipefail
cd /root/lab3
iostat -dx 1 > runs/o3-write-3000-4inst-iostat.log 2>&1 &
IOPID=$!
scripts/run3.sh o3-write-3000-4inst -url http://127.0.0.1:8080/api/enroll \
  -body '{"student":"s","course":"c"}' -plan '3000@120s' 2>&1 | tail -3
kill $IOPID 2>/dev/null || true
wait $IOPID 2>/dev/null || true
echo "DONE"
