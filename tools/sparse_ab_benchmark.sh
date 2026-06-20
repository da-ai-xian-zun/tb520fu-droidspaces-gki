#!/bin/sh
# Run inside a running container (directory or sparse). Outputs one-line summary.
set -u

label="${1:-unknown}"

bench_ms() {
  local name="$1"
  shift
  local t0 t1 ms
  t0=$(date +%s%N 2>/dev/null || echo 0)
  "$@" >/dev/null 2>&1
  t1=$(date +%s%N 2>/dev/null || echo 0)
  if [ "$t0" != "0" ] && [ "$t1" != "0" ]; then
    ms=$(( (t1 - t0) / 1000000 ))
    echo "${label} ${name}: ${ms} ms"
  fi
}

echo "========== BENCH $label =========="
mount | grep -E ' / |ext4|f2fs' | head -5
df -hT / /tmp /var/cache/apt 2>/dev/null | head -5

bench_ms "stat_x500" sh -c 'for i in $(seq 1 500); do stat /etc/passwd >/dev/null; done'
bench_ms "ls_usr_share" ls -1 /usr/share
bench_ms "find_usr_share_d2" find /usr/share -maxdepth 2 -type f
bench_ms "find_root_d2" find /root -maxdepth 2 2>/dev/null

if command -v apt-get >/dev/null 2>&1; then
  bench_ms "apt_update" apt-get update -qq
fi

echo "========== END $label =========="