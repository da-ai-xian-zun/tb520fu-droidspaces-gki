#!/system/bin/sh
# Fill existing ext4 image from debian-cli rootfs (resume after partial create)
set -eu

SRC=/data/local/Droidspaces/Containers/debian-cli/rootfs
IMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
MP=/data/local/tmp/sparse-ab-fill-mnt
mkdir -p "$MP"

if [ ! -f "$IMG" ]; then
  echo "ERROR: no image"
  exit 1
fi

chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

# detach stale loops
umount "$MP" 2>/dev/null || true
for i in $(seq 48 63); do
  losetup -d /dev/block/loop$i 2>/dev/null || true
done

FREE=""
for i in $(seq 48 63); do
  if ! losetup /dev/block/loop$i 2>/dev/null; then
    FREE=$i
    break
  fi
done
if [ -z "$FREE" ]; then
  echo "ERROR: no free loop"
  exit 1
fi

echo "Attach loop$FREE"
if ! losetup /dev/block/loop$FREE "$IMG" 2>&1; then
  echo "losetup failed; trying if already attached elsewhere"
  losetup -a | grep -F "$IMG" || true
  for i in $(seq 48 63); do
    if losetup -a 2>/dev/null | grep -q "loop$i"; then
      if losetup -a 2>/dev/null | grep "loop$i" | grep -qF "$IMG"; then
        FREE=$i
        echo "reuse loop$i"
        break
      fi
    fi
  done
fi

mount -t ext4 -o rw /dev/block/loop$FREE "$MP"
echo "Mounted; checking if already filled..."
if [ -f "$MP/etc/debian_version" ]; then
  echo "Image already has debian rootfs; skip copy"
else
  echo "Copying via tar..."
  t0=$(date +%s)
  (cd "$SRC" && tar -cf - .) | (cd "$MP" && tar -xf -)
  t1=$(date +%s)
  echo "Copy done in $((t1 - t0))s"
fi

sync
umount "$MP"
losetup -d /dev/block/loop$FREE 2>/dev/null || true
echo "Fill complete: $(du -h "$IMG" | awk '{print $1}')"
ls -lh "$IMG"