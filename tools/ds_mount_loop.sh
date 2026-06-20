#!/system/bin/sh
# Root-fix loop mount helper: explicit losetup loop48+ then mount.
# Drop-in replacement for broken `mount -o loop` on APEX-heavy Android.
# Usage: ds_mount_loop.sh <img> <mountpoint> [extra_mount_opts]
set -u

IMG="$1"
MNT="$2"
EXTRA="${3:-rw}"

[ -f "$IMG" ] || { echo "ds_mount_loop: image not found: $IMG"; exit 1; }
mkdir -p "$MNT"

max_loop=64
start=48
[ -r /sys/module/loop/parameters/max_loop ] && max_loop=$(cat /sys/module/loop/parameters/max_loop)
[ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))

chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

i=$((max_loop - 1))
while [ "$i" -ge "$start" ]; do
  dev="/dev/block/loop$i"
  if losetup "$dev" 2>/dev/null; then
    i=$((i - 1))
    continue
  fi
  if losetup "$dev" "$IMG" 2>/dev/null; then
    if mount -t ext4 -o "$EXTRA" "$dev" "$MNT" 2>/dev/null; then
      echo "ds_mount_loop: OK loop$i -> $MNT"
      exit 0
    fi
    umount "$MNT" 2>/dev/null || true
    losetup -d "$dev" 2>/dev/null || true
  fi
  i=$((i - 1))
done

echo "ds_mount_loop: FAILED for $IMG"
exit 1