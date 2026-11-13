#!/usr/bin/env bash
set -euo pipefail
cd /root/lab3

LB=http://127.0.0.1:8090

wait_backends() {
  local want=$1
  for i in $(seq 1 60); do
    n=$(curl -fsS "$LB/backends" 2>/dev/null | grep -c '"up": *true' || true)
    [ "$n" -ge "$want" ] && echo "  ready: $n" && return 0
    sleep 3
  done
  echo "  WARN not ready: $n"
}

run_write() {
  local name=$1 replicas=$2
  echo "=== $name (replicas=$replicas) ==="
  systemctl stop lab3-scaler 2>/dev/null || true
  systemctl reset-failed lab3-scaler 2>/dev/null || true
  sleep 2
  rm -f data/targets.json data/run-start data/lbd-events.csv data/decisions.csv data/instances.csv
  systemd-run --unit=lab3-scaler --working-directory=/root/lab3 -- \
    /root/lab3/bin/scaler -mode fixed -replicas "$replicas" \
    -data /root/lab3/data -lb "$LB" >/dev/null 2>&1
  wait_backends "$replicas"
  sleep 5
  iostat -dx 1 > "runs/$name-iostat.log" 2>&1 &
  local iopid=$!
  scripts/run3.sh "$name" -url http://127.0.0.1:8080/api/enroll \
    -body '{"student":"s","course":"c"}' -plan '1500@120s' 2>&1 | tail -3
  kill $iopid 2>/dev/null || true
  wait $iopid 2>/dev/null || true
  echo "  done: $name"
}

run_write o3-write-1500-4inst 4
run_write o3-write-1500-8inst 8

systemctl stop lab3-scaler 2>/dev/null || true
echo "=== DONE ==="
