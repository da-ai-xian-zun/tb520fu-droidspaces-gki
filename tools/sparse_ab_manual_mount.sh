#!/system/bin/sh
# Workaround: manual losetup+mount ext4, then directory-mode container (I/O equivalent to sparse)
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
TEST=debian-cli-sparse-test
BASE=/data/local/Droidspaces/Containers/debian-cli-sparse-test
IMG="$BASE/rootfs.img"
MP="$BASE/rootfs"
LOG=/data/local/tmp/sparse_ab_results.txt

cleanup_mount() {
  "$DS" --name="$TEST" stop 2>/dev/null || true
  sleep 2
  umount "$MP" 2>/dev/null || true
  for i in $(seq 48 63); do
    if losetup -a 2>/dev/null | grep -q "loop$i"; then
      if losetup -a 2>/dev/null | grep "loop$i" | grep -qF "$IMG"; then
        losetup -d /dev/block/loop$i 2>/dev/null || true
      fi
    fi
  done
}

setup_mount() {
  mkdir -p "$MP"
  chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
  FREE=""
  for i in $(seq 48 63); do
    losetup /dev/block/loop$i 2>/dev/null && continue
    FREE=$i
    break
  done
  if [ -z "$FREE" ]; then
    echo "ERROR: no free loop 48-63"
    exit 1
  fi
  echo "Using loop$FREE for manual mount"
  if ! losetup /dev/block/loop$FREE "$IMG" 2>&1; then
    echo "losetup failed; checking existing binding"
    losetup -a | grep -F "$IMG" || true
    for i in $(seq 48 63); do
      if losetup -a 2>/dev/null | grep "loop$i" | grep -qF "$IMG"; then
        FREE=$i
        break
      fi
    done
  fi
  mount -t ext4 -o rw /dev/block/loop$FREE "$MP"
  echo "Mounted: $(mount | grep sparse-test)"
  echo "loop$FREE" > /data/local/tmp/sparse_ab_loop_num
}

BENCH='echo "========== BENCH sparse-manual =========="; mount | head -10; df -h / /tmp 2>/dev/null | head -4; t0=$(date +%s%N); for i in $(seq 1 500); do stat /etc/passwd >/dev/null; done; t1=$(date +%s%N); echo "sparse stat_x500: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); ls -1 /usr/share >/dev/null; t1=$(date +%s%N); echo "sparse ls_usr_share: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /usr/share -maxdepth 2 -type f >/dev/null; t1=$(date +%s%N); echo "sparse find_usr_share_d2: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /root -maxdepth 2 >/dev/null 2>&1; t1=$(date +%s%N); echo "sparse find_root_d2: $(( (t1-t0)/1000000 )) ms"; if command -v apt-get >/dev/null 2>&1; then t0=$(date +%s%N); apt-get update -qq >/dev/null 2>&1 || true; t1=$(date +%s%N); echo "sparse apt_update: $(( (t1-t0)/1000000 )) ms"; fi; echo "========== END sparse-manual =========="'

echo "=== manual sparse mount A/B (sparse leg) ===" | tee -a "$LOG"
cleanup_mount
setup_mount

# directory mode on loop-mounted ext4
"$DS" --name="$TEST" --rootfs="$MP" --hostname="$TEST" \
  --net=nat --upstream=wlan0 --dns=1.1.1.1,8.8.8.8 start 2>&1 | tee -a "$LOG"
sleep 8
"$DS" show 2>&1 | tee -a "$LOG"
if "$DS" show 2>/dev/null | grep -q "$TEST"; then
  "$DS" --name="$TEST" run sh -c "$BENCH" 2>&1 | tee -a "$LOG"
  "$DS" --name="$TEST" stop 2>&1 | tee -a "$LOG"
else
  echo "ERROR: sparse manual container failed to start" | tee -a "$LOG"
fi
sleep 2
cleanup_mount
echo "=== directory baseline (from earlier run) ===" | tee -a "$LOG"
grep -E 'stat_x500|ls_usr_share|find_|apt_update' "$LOG" | head -20
echo "=== DONE manual ===" | tee -a "$LOG"