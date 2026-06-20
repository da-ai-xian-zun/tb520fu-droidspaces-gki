#!/system/bin/sh
# Migrate debian-cli directory rootfs -> 32G sparse rootfs.img (CLI path)
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian-cli
BASE=/data/local/Droidspaces/Containers/$NAME
SRC="$BASE/rootfs"
IMG="$BASE/rootfs.img"
OLD="$BASE/rootfs.dir.bak"
MP=/data/local/tmp/debian-cli-sparse-migrate-mnt
SIZE_G="${SIZE_G:-32}"

[ -d "$SRC" ] || { echo "ERROR: no $SRC"; exit 1; }
[ -f "$BASE/container.config" ] || { echo "ERROR: no container.config"; exit 1; }

if [ -f "$IMG" ]; then
  echo "ERROR: $IMG already exists. Remove manually or set FORCE=1 after backup."
  [ "${FORCE:-0}" = "1" ] || exit 1
fi

echo "========== STOP $NAME =========="
"$DS" --name="$NAME" stop 2>/dev/null || true
sleep 3

# clean loops for migration only
umount "$MP" 2>/dev/null || true
for i in $(seq 48 63); do
  losetup -d /dev/block/loop$i 2>/dev/null || true
done
sync

USED_KB=$(du -sk "$SRC" | awk '{print $1}')
echo "Source rootfs: ${USED_KB}KB (~$((USED_KB/1024/1024))G used)"
echo "Creating ${SIZE_G}G sparse image at $IMG"

truncate -s ${SIZE_G}G "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
tune2fs -m 0 "$IMG" 2>/dev/null || true
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
[ -n "$FREE" ] || { echo "ERROR: no free loop"; exit 1; }

mkdir -p "$MP"
losetup /dev/block/loop$FREE "$IMG" 2>&1 || true
mount -t ext4 -o rw /dev/block/loop$FREE "$MP"

echo "Copying rootfs (tar pipe)..."
t0=$(date +%s)
(cd "$SRC" && tar -cf - .) | (cd "$MP" && tar -xf -)
sync
t1=$(date +%s)
echo "Copy done in $((t1-t0))s"

umount "$MP"
losetup -d /dev/block/loop$FREE 2>/dev/null || true
e2fsck -pf "$IMG" 2>/dev/null || true

echo "========== SWITCH CONFIG =========="
cp -a "$BASE/container.config" "$BASE/container.config.pre-sparse"

# move directory aside (delete after verify)
if [ -d "$OLD" ]; then
  rm -rf "$OLD"
fi
mv "$SRC" "$OLD"

# patch config for sparse
CFG="$BASE/container.config"
if grep -q '^rootfs_path=' "$CFG"; then
  sed -i "s|^rootfs_path=.*|rootfs_path=$IMG|" "$CFG"
else
  echo "rootfs_path=$IMG" >> "$CFG"
fi
if grep -q '^use_sparse_image=' "$CFG"; then
  sed -i 's|^use_sparse_image=.*|use_sparse_image=1|' "$CFG"
else
  echo 'use_sparse_image=1' >> "$CFG"
fi

echo "========== START $NAME (rootfs-img) =========="
"$DS" --name="$NAME" --rootfs-img="$IMG" --net=nat start 2>&1
sleep 8

if "$DS" show 2>/dev/null | grep -q "$NAME"; then
  echo "SUCCESS: $NAME running on sparse image"
  "$DS" --name="$NAME" run sh -c 'df -h /; cat /etc/debian_version; hostname' 2>&1
  echo ""
  echo "Backup directory kept at: $OLD"
  echo "After you verify, remove backup: rm -rf $OLD"
  ls -lh "$IMG"
  du -h "$IMG" | awk '{print "sparse actual:", $1}'
else
  echo "FAILED to start — restoring directory rootfs"
  mv "$OLD" "$SRC"
  cp -a "$BASE/container.config.pre-sparse" "$CFG"
  exit 1
fi