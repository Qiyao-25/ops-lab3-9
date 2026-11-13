#!/usr/bin/env bash
# O3 扩错层实验：写路径（sync=each）下扩实例是否有效
# 在 /root/lab3 下运行，需 prometheus、node_exporter、lbd 已启动
set -euo pipefail
cd /root/lab3

LB=http://127.0.0.1:8090
SCALER=http://127.0.0.1:8091

wait_backends() {
  local want=$1
  local i
  for i in $(seq 1 60); do
    local n
    n=$(curl -fsS "$LB/backends" 2>/dev/null | grep -c '"up": *true' || true)
    if [ "$n" -ge "$want" ]; then
      echo "  backends ready: $n (wanted $want) after ${i}*3s"
      return 0
    fi
    sleep 3
  done
  echo "  WARN: backends not ready, got $n (continuing anyway)"
  return 0
}

run_one() {
  local name=$1
  local replicas=$2
  local url=$3
  local plan=$4
  local body=${5:-}
  echo "=== $name (replicas=$replicas) ==="
  # stop scaler, clean data files
  systemctl stop lab3-scaler 2>/dev/null || true
  systemctl reset-failed lab3-scaler 2>/dev/null || true
  sleep 2
  rm -f data/targets.json data/run-start data/lbd-events.csv data/decisions.csv data/instances.csv
  # start scaler fixed
  systemd-run --unit=lab3-scaler --working-directory=/root/lab3 -- \
    /root/lab3/bin/scaler -mode fixed -replicas "$replicas" \
    -data /root/lab3/data -lb "$LB" >/dev/null 2>&1
  wait_backends "$replicas"
  sleep 5  # let it settle
  # run experiment
  if [ -n "$body" ]; then
    scripts/run3.sh "$name" -url "$url" -body "$body" -plan "$plan" 2>&1 | tail -5
  else
    scripts/run3.sh "$name" -url "$url" -plan "$plan" 2>&1 | tail -5
  fi
  echo "  done: $name"
}

# Write path: POST /api/enroll, sync=each (default). Load 400 rps for 120s.
WRITE_PLAN="400@120s"
WRITE_URL="http://127.0.0.1:8080/api/enroll"
WRITE_BODY='{"student":"s","course":"c"}'

run_one o3-write-1inst 1 "$WRITE_URL" "$WRITE_PLAN" "$WRITE_BODY"
run_one o3-write-2inst 2 "$WRITE_URL" "$WRITE_PLAN" "$WRITE_BODY"
run_one o3-write-4inst 4 "$WRITE_URL" "$WRITE_PLAN" "$WRITE_BODY"

# Read path: GET /api/courses/1. Load 600 rps for 120s (above 4-instance capacity).
READ_PLAN="600@120s"
READ_URL="http://127.0.0.1:8080/api/courses/1"

run_one o3-read-1inst 1 "$READ_URL" "$READ_PLAN"
run_one o3-read-2inst 2 "$READ_URL" "$READ_PLAN"
run_one o3-read-4inst 4 "$READ_URL" "$READ_PLAN"

# stop scaler
systemctl stop lab3-scaler 2>/dev/null || true
echo "=== ALL O3 EXPERIMENTS DONE ==="
ls -d runs/o3-*
