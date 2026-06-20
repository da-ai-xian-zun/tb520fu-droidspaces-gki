#!/system/bin/sh
set -eu
BB=/data/local/Droidspaces/bin/busybox
SCRIPT=/data/user/0/com.droidspaces.app/cache/mount_loop_scan.sh
IMG=/data/local/tmp/diag-mount-test.img
MNT=/data/local/tmp/diag-mount-test-mnt

echo "=== diag mount $(date) ==="
echo "[*] max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo ?)"
echo "[*] /proc/loops lines=$(wc -l /proc/loops 2>/dev/null || echo 0)"
echo "[*] losetup -a count=$(losetup -a 2>/dev/null | wc -l)"

rm -f "$IMG"
rm -rf "$MNT"
mkdir -p "$MNT"

echo "[*] small image test"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

echo "--- busybox loop ---"
if "$BB" mount -t ext4 -o loop,rw "$IMG" "$MNT" 2>&1; then
  echo "busybox: OK"; umount "$MNT" || true
else
  echo "busybox: FAIL exit=$?"
fi

echo "--- system loop ---"
if mount -t ext4 -o loop,rw "$IMG" "$MNT" 2>&1; then
  echo "system: OK"; umount "$MNT" || true
else
  echo "system: FAIL exit=$?"
fi

echo "--- mount_loop_scan.sh ---"
if [ -f "$SCRIPT" ]; then
  BUSYBOX_PATH="$BB" sh "$SCRIPT" "$IMG" "$MNT" "rw" 2>&1 && echo "script: OK" || echo "script: FAIL exit=$?"
  umount "$MNT" 2>/dev/null || true
  for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do losetup -d "$d" 2>/dev/null; done
else
  echo "script: MISSING"
fi

echo "--- ds_mount_loop ---"
DS=/data/local/tmp/ds_mount_loop.sh
if [ -f "$DS" ]; then
  sh "$DS" "$IMG" "$MNT" rw 2>&1 || echo "ds: FAIL exit=$?"
  umount "$MNT" 2>/dev/null || true
  for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do losetup -d "$d" 2>/dev/null; done
fi

echo "--- loop48-63 probe ---"
i=63
while [ "$i" -ge 48 ]; do
  dev="/dev/block/loop$i"
  if losetup "$dev" 2>/dev/null; then
    echo "loop$i: busy"
  else
    if losetup "$dev" "$IMG" 2>/dev/null; then
      if mount -t ext4 -o rw "$dev" "$MNT" 2>/dev/null; then
        echo "loop$i: mount OK"
        umount "$MNT"
        losetup -d "$dev"
        break
      else
        echo "loop$i: losetup OK mount FAIL"
        losetup -d "$dev" 2>/dev/null || true
      fi
    else
      echo "loop$i: losetup FAIL"
    fi
  fi
  i=$((i - 1))
done

rm -f "$IMG"
rmdir "$MNT" 2>/dev/null || true
echo "=== done ==="