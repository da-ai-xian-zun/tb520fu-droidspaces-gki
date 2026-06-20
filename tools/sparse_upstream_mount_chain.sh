#!/system/bin/sh
# Test exact stock SparseImageInstaller mount chain (76cbd21) without touching production containers.
set -u

BASE=/data/local/Droidspaces/Containers/upstream-mount-test
IMG="$BASE/rootfs.img"
MP=/data/local/tmp/upstream-mount-test-mnt
BB=/data/local/Droidspaces/bin/busybox
OPTS="loop,rw,nodelalloc,noatime,nodiratime,init_itable=0"

mkdir -p "$BASE" "$MP"
rm -f "$IMG" 2>/dev/null
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

echo "=== upstream_mount_chain $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
echo "model: $(getprop ro.product.model)"
echo "kernel: $(uname -r)"
echo "max_loop: $(cat /sys/module/loop/parameters/max_loop 2>/dev/null)"
echo "losetup bound: $(losetup -a 2>/dev/null | wc -l)"
echo

echo "=== 1) busybox only (App options) ==="
umount "$MP" 2>/dev/null || true
"$BB" mount -t ext4 -o "$OPTS" "$IMG" "$MP" 2>&1
echo "exit=$?"
mount | grep -q upstream-mount-test-mnt && { echo RESULT_busybox_only: SUCCESS; umount "$MP" 2>/dev/null || true; } || echo RESULT_busybox_only: FAILED
echo

echo "=== 2) system mount only (App options) ==="
umount "$MP" 2>/dev/null || true
mount -t ext4 -o "$OPTS" "$IMG" "$MP" 2>&1
echo "exit=$?"
mount | grep -q upstream-mount-test-mnt && { echo RESULT_system_only: SUCCESS; umount "$MP" 2>/dev/null || true; } || echo RESULT_system_only: FAILED
echo

echo "=== 3) stock SparseImageInstaller chain: busybox || system mount ==="
umount "$MP" 2>/dev/null || true
sh -c "\"$BB\" mount -t ext4 -o $OPTS \"$IMG\" \"$MP\" || mount -t ext4 -o $OPTS \"$IMG\" \"$MP\"" 2>&1
echo "chain_exit=$?"
mount | grep -q upstream-mount-test-mnt && { echo RESULT_upstream_chain: SUCCESS; umount "$MP" 2>/dev/null || true; } || echo RESULT_upstream_chain: FAILED
echo

echo "=== 4) explicit losetup loop48+ (control) ==="
umount "$MP" 2>/dev/null || true
FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
echo "free_loop: ${FREE:-none}"
if [ -n "$FREE" ]; then
  losetup /dev/block/loop$FREE "$IMG" 2>&1
  mount -t ext4 -o rw,nodelalloc,noatime,nodiratime,init_itable=0 /dev/block/loop$FREE "$MP" 2>&1
  mount | grep -q upstream-mount-test-mnt && { echo RESULT_explicit_losetup: SUCCESS; umount "$MP" 2>/dev/null || true; losetup -d /dev/block/loop$FREE 2>/dev/null || true; } || echo RESULT_explicit_losetup: FAILED
fi

rmdir "$MP" 2>/dev/null || true
rm -rf "$BASE" 2>/dev/null || true
echo "=== end ==="