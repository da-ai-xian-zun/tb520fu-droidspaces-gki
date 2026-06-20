#!/system/bin/sh
IMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
MP=/data/local/tmp/sparse-ab-fill-mnt
mkdir -p "$MP"

echo "=== tune2fs ==="
tune2fs -l "$IMG" 2>&1 | head -8 || echo "not ext4 yet"

if ! tune2fs -l "$IMG" >/dev/null 2>&1; then
  echo "=== mkfs.ext4 ==="
  mkfs.ext4 -F "$IMG" 2>&1 | tail -3
fi

chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

for i in 48 49 50; do
  losetup /dev/block/loop$i 2>/dev/null && continue
  echo "=== losetup loop$i ==="
  losetup /dev/block/loop$i "$IMG" 2>&1
  echo "losetup exit=$?"
  losetup -a | grep "loop$i" || true
  mount -t ext4 -o rw /dev/block/loop$i "$MP" 2>&1
  echo "mount exit=$?"
  if mount | grep -q sparse-ab-fill-mnt; then
    echo "SUCCESS mounted"
    df -hT "$MP"
    umount "$MP"
    losetup -d /dev/block/loop$i
    exit 0
  fi
  losetup -d /dev/block/loop$i 2>/dev/null || true
done
echo "FAILED all loops"
exit 1