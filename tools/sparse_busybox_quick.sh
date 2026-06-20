#!/system/bin/sh
set -u
IMG="${1:-/data/local/Droidspaces/Containers/test/rootfs.img}"
MP=/data/local/tmp/sparse-cmp-mnt
BB=/data/local/Droidspaces/bin/busybox
mkdir -p "$MP"
echo "=== ENV ==="
getprop ro.product.model
uname -r
echo -n "max_loop: "; cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "?"
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
echo "img: $IMG"
echo
echo "=== busybox mount -o loop ==="
umount "$MP" 2>/dev/null || true
"$BB" mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q sparse-cmp-mnt; then
  echo "RESULT busybox: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "RESULT busybox: FAILED"
fi
echo
echo "=== toybox mount -o loop ==="
umount "$MP" 2>/dev/null || true
mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q sparse-cmp-mnt; then
  echo "RESULT toybox: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "RESULT toybox: FAILED"
fi