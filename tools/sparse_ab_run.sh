#!/system/bin/sh
# Cautious sparse A/B: directory debian-cli vs sparse test container
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
TEST=debian-cli-sparse-test
IMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
LOG=/data/local/tmp/sparse_ab_results.txt

BENCH_CMD='label="$1"; echo "========== BENCH $label =========="; mount | head -8; df -h / /tmp 2>/dev/null | head -4; t0=$(date +%s%N); for i in $(seq 1 500); do stat /etc/passwd >/dev/null; done; t1=$(date +%s%N); echo "$label stat_x500: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); ls -1 /usr/share >/dev/null; t1=$(date +%s%N); echo "$label ls_usr_share: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /usr/share -maxdepth 2 -type f >/dev/null; t1=$(date +%s%N); echo "$label find_usr_share_d2: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /root -maxdepth 2 >/dev/null 2>&1; t1=$(date +%s%N); echo "$label find_root_d2: $(( (t1-t0)/1000000 )) ms"; if command -v apt-get >/dev/null 2>&1; then t0=$(date +%s%N); apt-get update -qq >/dev/null 2>&1 || true; t1=$(date +%s%N); echo "$label apt_update: $(( (t1-t0)/1000000 )) ms"; fi; echo "========== END $label =========="'

: > "$LOG"

is_running() {
  "$DS" show 2>/dev/null | grep -q "$1"
}

run_bench() {
  local name="$1"
  local label="$2"
  echo "===== Starting $name ($label) =====" | tee -a "$LOG"
  if is_running "$name"; then
    "$DS" --name="$name" stop 2>/dev/null || true
    sleep 3
  fi
  if [ "$name" = "$TEST" ]; then
    if [ ! -f "$IMG" ]; then
      echo "ERROR: missing $IMG" | tee -a "$LOG"
      return 1
    fi
    "$DS" --name="$name" --rootfs-img="$IMG" --hostname="$name" \
      --net=nat --upstream=wlan0 --dns=1.1.1.1,8.8.8.8 start 2>&1 | tee -a "$LOG"
  else
    "$DS" --name="$name" --net=nat start 2>&1 | tee -a "$LOG"
  fi
  sleep 8
  if ! is_running "$name"; then
    echo "ERROR: $name failed to start" | tee -a "$LOG"
    "$DS" show 2>&1 | tee -a "$LOG"
    return 1
  fi
  "$DS" --name="$name" run sh -c "$BENCH_CMD" "$label" 2>&1 | tee -a "$LOG"
  "$DS" --name="$name" stop 2>&1 | tee -a "$LOG"
  sleep 3
  echo "===== Done $name =====" | tee -a "$LOG"
}

echo "========== SPARSE A/B RUN $(date) ==========" | tee "$LOG"
run_bench debian-cli directory
run_bench "$TEST" sparse
echo "========== FINAL =========="
cat "$LOG"