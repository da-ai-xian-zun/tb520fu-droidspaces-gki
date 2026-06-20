#!/system/bin/sh
# Generic OEM loop smoke: busybox / toybox mount -o loop vs explicit losetup.
# Scans loop0..(N-1) where N = count of /dev/block/loop* nodes.
set -u

IMG=/data/local/tmp/oem-loop-smoke.img
MP=/data/local/tmp/oem-loop-smoke-mnt
MAX=$(ls -d /sys/block/loop* 2>/dev/null | wc -l)
MAX=${MAX:-64}

echo "========== OEM LOOP SMOKE =========="
getprop ro.product.model
echo -n "loop nodes: "; echo "$MAX"
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "max_loop_sysfs: (unreadable)"
echo

rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
truncate -s 64M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
mkdir -p "$MP"
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

BB=""
for c in /data/adb/ksu/bin/busybox /data/local/Droidspaces/bin/busybox /system/bin/busybox; do
  if [ -x "$c" ]; then BB=$c; break; fi
done
echo "busybox: ${BB:-none}"

if [ -n "$BB" ]; then
  echo "--- busybox mount -o loop ---"
  "$BB" mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
  echo "exit=$?"
  if mount | grep -q oem-loop-smoke-mnt; then
    echo "RESULT busybox_loop: SUCCESS"
    umount "$MP" 2>/dev/null || true
  else
    echo "RESULT busybox_loop: FAILED"
  fi
fi

echo "--- toybox mount -o loop ---"
mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q oem-loop-smoke-mnt; then
  echo "RESULT toybox_loop: SUCCESS"
  umount "$MP" 2>/dev/null || true
else
  echo "RESULT toybox_loop: FAILED"
fi

FREE=""
i=$((MAX - 1))
while [ "$i" -ge 0 ]; do
  if ! losetup /dev/block/loop$i 2>/dev/null; then
    FREE=$i
    break
  fi
  i=$((i - 1))
done
echo "first free loop (high→0): ${FREE:-none}"
if [ -n "$FREE" ]; then
  losetup /dev/block/loop$FREE "$IMG" 2>&1
  if mount -t ext4 -o rw /dev/block/loop$FREE "$MP" 2>&1; then
    if mount | grep -q oem-loop-smoke-mnt; then
      echo "RESULT explicit_losetup: SUCCESS"
      umount "$MP" 2>/dev/null || true
    else
      echo "RESULT explicit_losetup: MOUNT_FAILED"
    fi
    losetup -d /dev/block/loop$FREE 2>/dev/null || true
  else
    echo "RESULT explicit_losetup: LOSETUP_OR_MOUNT_FAILED"
    losetup -d /dev/block/loop$FREE 2>/dev/null || true
  fi
else
  echo "RESULT explicit_losetup: SKIPPED (no free loop)"
fi

rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null || true
echo "========== DONE =========="