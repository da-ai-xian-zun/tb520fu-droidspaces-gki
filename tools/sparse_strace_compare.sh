#!/system/bin/sh
# strace ioctl comparison: busybox mount -o loop vs explicit losetup (read-only img).
set -u

BB=/data/local/Droidspaces/bin/busybox
BASE=/data/local/Droidspaces/Containers/strace-test
IMG="$BASE/rootfs.img"
MP=/data/local/tmp/strace-test-mnt
LOG=/data/local/tmp/sparse_strace_compare.log

mkdir -p "$BASE" "$MP"
rm -f "$IMG" 2>/dev/null
truncate -s 64M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1

: > "$LOG"
echo "=== sparse_strace_compare $(date -u '+%Y-%m-%dT%H:%M:%SZ') ===" | tee -a "$LOG"
echo "bound=$(losetup -a 2>/dev/null | wc -l) max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null)" | tee -a "$LOG"

if ! command -v strace >/dev/null 2>&1; then
  echo "ERROR: strace not found" | tee -a "$LOG"
  exit 1
fi

echo "--- busybox mount -o loop (ioctl summary) ---" | tee -a "$LOG"
umount "$MP" 2>/dev/null || true
strace -f -e trace=ioctl,openat,close -o /data/local/tmp/strace-busybox.log \
  "$BB" mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1 | tee -a "$LOG" || true
grep -E 'LOOP_|loop|ioctl' /data/local/tmp/strace-busybox.log 2>/dev/null | tail -30 | tee -a "$LOG"
umount "$MP" 2>/dev/null || true

FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
echo "free_loop=$FREE" | tee -a "$LOG"

if [ -n "$FREE" ]; then
  echo "--- explicit losetup loop$FREE (ioctl summary) ---" | tee -a "$LOG"
  strace -f -e trace=ioctl,openat,close -o /data/local/tmp/strace-losetup.log \
    losetup /dev/block/loop$FREE "$IMG" 2>&1 | tee -a "$LOG" || true
  grep -E 'LOOP_|loop|ioctl' /data/local/tmp/strace-losetup.log 2>/dev/null | tail -30 | tee -a "$LOG"
  losetup -d /dev/block/loop$FREE 2>/dev/null || true
fi

rm -rf "$BASE" 2>/dev/null || true
rmdir "$MP" 2>/dev/null || true
echo "=== end (full logs: /data/local/tmp/strace-busybox.log /data/local/tmp/strace-losetup.log) ===" | tee -a "$LOG"