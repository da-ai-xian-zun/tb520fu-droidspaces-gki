#!/system/bin/sh
# Verify SparseImageInstaller one-liner after ; join fix
IMG=/data/local/tmp/mount-oneliner-test.img
MNT=/data/local/tmp/mount-oneliner-test-mnt
OPTS="rw,nodelalloc,noatime,nodiratime,init_itable=0"
BB=/data/local/Droidspaces/bin/busybox

rm -f "$IMG"; rm -rf "$MNT"
mkdir -p "$MNT"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

# Kotlin: .replace("\n", "; ")
CMD='max_loop=64
if [ -r /sys/module/loop/parameters/max_loop ]; then
  max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo 64)
fi
start=48
[ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))
i=$((max_loop - 1))
mounted=0
while [ "$i" -ge "$start" ]; do
  loop_dev="/dev/block/loop$i"
  if losetup "$loop_dev" 2>/dev/null; then
    i=$((i - 1))
    continue
  fi
  if losetup "$loop_dev" "'"$IMG"'" 2>/dev/null; then
    if mount -t ext4 -o '"$OPTS"' "$loop_dev" "'"$MNT"'" 2>/dev/null; then
      mounted=1
      break
    fi
    umount "'"$MNT"'" 2>/dev/null || true
    losetup -d "$loop_dev" 2>/dev/null || true
  fi
  i=$((i - 1))
done
if [ "$mounted" != 1 ]; then
  '"$BB"' mount -t ext4 -o loop,'"$OPTS"' "'"$IMG"'" "'"$MNT"'" 2>/dev/null || \
  mount -t ext4 -o loop,'"$OPTS"' "'"$IMG"'" "'"$MNT"'" 2>/dev/null || exit 1
fi'

ONELINER=$(printf '%s' "$CMD" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/; /; /g')
# simulate broken: newline -> space only
BROKEN=$(printf '%s' "$CMD" | tr '\n' ' ' | sed 's/  */ /g')

echo "=== BROKEN (space join) ==="
sh -c "$BROKEN" && echo BROKEN_OK || echo BROKEN_FAIL:$?
umount "$MNT" 2>/dev/null; losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r d; do losetup -d "$d"; done

echo "=== FIXED (semicolon join) ==="
FIXED=$(printf '%s' "$CMD" | tr '\n' ';')
sh -c "$FIXED" && echo FIXED_OK || echo FIXED_FAIL:$?
mount | grep "$MNT" && echo MOUNTED
umount "$MNT" 2>/dev/null
losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r d; do losetup -d "$d"; done
rm -f "$IMG"; rmdir "$MNT" 2>/dev/null