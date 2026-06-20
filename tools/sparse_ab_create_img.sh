#!/system/bin/sh
# Create sparse test image from debian-cli rootfs (does NOT modify debian-cli)
set -eu

SRC=/data/local/Droidspaces/Containers/debian-cli/rootfs
BASE=/data/local/Droidspaces/Containers/debian-cli-sparse-test
IMG="$BASE/rootfs.img"
MP=/data/local/tmp/sparse-ab-fill-mnt
SIZE_G=3

if [ ! -d "$SRC" ]; then
  echo "ERROR: source rootfs missing: $SRC"
  exit 1
fi

mkdir -p "$BASE" "$MP"

if [ -f "$IMG" ]; then
  echo "Image already exists: $IMG ($(du -h "$IMG" | awk '{print $1}'))"
  echo "Skip creation. Delete manually to recreate."
  exit 0
fi

echo "Creating ${SIZE_G}G ext4 image at $IMG ..."
truncate -s ${SIZE_G}G "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
if [ -z "$FREE" ]; then
  echo "ERROR: no free loop in 48-63"
  exit 1
fi

echo "Using loop$FREE"
losetup /dev/block/loop$FREE "$IMG"
mount -t ext4 -o rw /dev/block/loop$FREE "$MP"

echo "Copying rootfs via tar (may take several minutes)..."
t0=$(date +%s)
(cd "$SRC" && tar -cf - .) | (cd "$MP" && tar -xf -)
t1=$(date +%s)
echo "Copy done in $((t1 - t0))s"

sync
umount "$MP"
losetup -d /dev/block/loop$FREE 2>/dev/null || true

echo "Image ready: $(ls -lh "$IMG")"
du -sh "$IMG"
echo "DONE create"