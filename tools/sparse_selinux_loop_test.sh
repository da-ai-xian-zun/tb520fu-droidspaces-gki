#!/system/bin/sh
# Test whether SELinux permissive changes Droidspaces busybox mount -o loop.
set -u

IMG=/data/local/tmp/selinux-loop-test.img
MP=/data/local/tmp/selinux-loop-test-mnt
BB=/data/local/Droidspaces/bin/busybox

echo "========== SELINUX LOOP TEST =========="
getprop ro.product.model
echo -n "getenforce before: "; getenforce 2>/dev/null || true

echo "--- setenforce 0 ---"
setenforce 0 2>&1
echo -n "getenforce after: "; getenforce 2>/dev/null || true

rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
truncate -s 64M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
mkdir -p "$MP"
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

if [ ! -x "$BB" ]; then
  echo "ERROR: no Droidspaces busybox at $BB"
  exit 1
fi

echo "--- Droidspaces busybox mount -o loop (permissive) ---"
"$BB" mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q selinux-loop-test-mnt; then
  echo "RESULT busybox_permissive: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "RESULT busybox_permissive: FAILED"
fi

echo "--- toybox mount -o loop (permissive, control) ---"
mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q selinux-loop-test-mnt; then
  echo "RESULT toybox_permissive: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "RESULT toybox_permissive: FAILED"
fi

echo "--- restore enforcing ---"
setenforce 1 2>&1 || true
echo -n "getenforce restored: "; getenforce 2>/dev/null || true

rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
echo "========== DONE =========="