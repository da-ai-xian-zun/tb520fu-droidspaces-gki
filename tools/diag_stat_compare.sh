#!/bin/bash
bench_stat() {
  local label="$1" path="$2" n="$3"
  local t0 t1 ms
  t0=$(date +%s%N)
  for i in $(seq 1 "$n"); do stat "$path" >/dev/null 2>&1; done
  t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 ))
  echo "$label stat x$n: ${ms} ms (avg $(( ms * 1000 / n )) us)"
}

echo "========== STAT BENCHMARK =========="
bench_stat "f2fs /etc/passwd" /etc/passwd 500
bench_stat "f2fs /usr/share" /usr/share 200

cp /etc/passwd /tmp/passwd.bench
bench_stat "tmpfs /tmp/passwd.bench" /tmp/passwd.bench 500

echo
echo "========== SELINUX =========="
getenforce 2>/dev/null || echo "(no getenforce)"
ls -Z /etc/passwd 2>/dev/null || true

echo
echo "========== DOLPHIN SETTINGS =========="
cat /root/.config/dolphinrc 2>/dev/null || true