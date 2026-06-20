#!/system/bin/sh
# Phase 0: read-only state check before sparse A/B (TB520FU)
set -u

DS=/data/local/Droidspaces/bin/droidspaces
BASE=/data/local/Droidspaces/Containers
TEST_NAME=debian-cli-sparse-test

echo "========== DEVICE =========="
getprop ro.product.model
getprop ro.build.display.id
echo

echo "========== LOOP POOL =========="
cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "(no max_loop)"
echo -n "loop nodes: "; ls /dev/block/loop* 2>/dev/null | wc -l
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
echo

echo "========== DISK =========="
df -hT /data 2>/dev/null || df -h /data
echo

echo "========== DROIDSPACES =========="
if [ -x "$DS" ]; then
  "$DS" show 2>&1 || true
else
  echo "ERROR: droidspaces not found"
fi
echo

for c in debian-cli debian13 "$TEST_NAME"; do
  echo "========== CONTAINER: $c =========="
  if [ -d "$BASE/$c" ]; then
    grep -E '^(name|rootfs_path|use_sparse|net_mode|bind_mounts)=' "$BASE/$c/container.config" 2>/dev/null || true
    du -sh "$BASE/$c/rootfs" 2>/dev/null || true
    ls -la "$BASE/$c/" 2>/dev/null | head -8
    if [ -f "$BASE/$c/rootfs.img" ]; then
      ls -lh "$BASE/$c/rootfs.img"
    fi
  else
    echo "(not present)"
  fi
  echo
done

echo "========== LOOP SMOKE (64M) =========="
IMG=/data/local/tmp/sparse-ab-smoke.img
MP=/data/local/tmp/sparse-ab-smoke-mnt
rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
truncate -s 64M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
mkdir -p "$MP"
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

echo "--- mount -o loop ---"
if mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1; then
  echo "mount -o loop: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "mount -o loop: FAILED"
fi

FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
echo "first free loop 48-63: ${FREE:-none}"
if [ -n "$FREE" ]; then
  losetup /dev/block/loop$FREE "$IMG" 2>&1
  if mount -t ext4 -o rw /dev/block/loop$FREE "$MP" 2>&1; then
    echo "explicit losetup+mount: SUCCESS"
    umount "$MP" 2>/dev/null || true
    losetup -d /dev/block/loop$FREE 2>/dev/null || true
  else
    echo "explicit losetup+mount: FAILED"
    losetup -d /dev/block/loop$FREE 2>/dev/null || true
  fi
fi
rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
echo
echo "========== DONE phase0 =========="