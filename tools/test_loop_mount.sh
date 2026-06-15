#!/system/bin/sh
set -e
IMG=/data/local/tmp/test-loop.img
MP=/data/local/tmp/test-loop-mnt
rm -f "$IMG"
rmdir "$MP" 2>/dev/null || true
truncate -s 64M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
mkdir -p "$MP"
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
echo "=== try mount minimal ==="
mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1 || echo "minimal mount fail: $?"
echo "=== try mount app options ==="
umount "$MP" 2>/dev/null || true
mount -t ext4 -o loop,rw,nodelalloc,noatime,nodiratime,init_itable=0 "$IMG" "$MP" 2>&1 || echo "app options mount fail: $?"
if mount | grep -q test-loop-mnt; then
  echo "MOUNT OK"
  umount "$MP"
else
  echo "MOUNT FAILED"
fi
dmesg | tail -15
rm -f "$IMG"
rmdir "$MP" 2>/dev/null || true