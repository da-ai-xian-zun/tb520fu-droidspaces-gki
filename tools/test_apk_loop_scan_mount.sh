#!/system/bin/sh
# Simulates SparseImageInstaller.buildLoopScanMountCmd (loopfix APK) on device.
set -u
IMG="${1:-/data/local/Droidspaces/Containers/sb-cli-test/rootfs.img}"
MNT="${2:-/data/local/tmp/sparse-apk-test-mnt}"
OPTS="rw,nodelalloc,noatime,nodiratime,init_itable=0"

echo "========== APK loop-scan mount test =========="
echo "img=$IMG mnt=$MNT"
losetup -a 2>/dev/null | wc -l | xargs echo "bound loops:"

mkdir -p "$(dirname "$IMG")" "$MNT"
rm -f "$IMG"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

max_loop=64
if [ -r /sys/module/loop/parameters/max_loop ]; then
  max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo 64)
fi
start=48
[ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))
i=$((max_loop - 1))
mounted=0
while [ "$i" -ge "$start" ]; do
  loop_dev="/dev/block/loop$i"
  if losetup "$loop_dev" 2>/dev/null; then
    i=$((i - 1))
    continue
  fi
  if losetup "$loop_dev" "$IMG" 2>/dev/null; then
    if mount -t ext4 -o $OPTS "$loop_dev" "$MNT" 2>/dev/null; then
      mounted=1
      echo "RESULT: SUCCESS loop=$i"
      break
    fi
    umount "$MNT" 2>/dev/null || true
    losetup -d "$loop_dev" 2>/dev/null || true
  fi
  i=$((i - 1))
done

if [ "$mounted" != 1 ]; then
  echo "RESULT: FAILED loop-scan"
  /data/local/Droidspaces/bin/busybox mount -t ext4 -o loop,$OPTS "$IMG" "$MNT" 2>&1
  echo "busybox fallback exit=$?"
  mount | grep -q "$MNT" && echo "RESULT: busybox fallback SUCCESS" || echo "RESULT: all FAILED"
fi

umount "$MNT" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r dev; do
  losetup -d "$dev" 2>/dev/null || true
done
rmdir "$MNT" 2>/dev/null || true
echo "========== DONE =========="