#!/system/bin/sh
# Isolate loop-mount failure from KernelSU modules (TB520FU)
# Usage:
#   sh sparse_ab_module_isolate.sh scan
#   sh sparse_ab_module_isolate.sh disable-nonessential
#   sh sparse_ab_module_isolate.sh smoke
#   sh sparse_ab_module_isolate.sh restore
set -u

MARKER=/data/local/tmp/sparse_ab_disabled_modules.list
# Must keep: Droidspaces daemon + Zygisk root stack (SukiSU)
KEEP_IDS='droidspaces zygisksu zygisk-sui'

scan_modules() {
  echo "========== KSU MODULES =========="
  for d in /data/adb/modules/*; do
    [ -d "$d" ] || continue
    id=$(basename "$d")
    st="ENABLED"
    [ -f "$d/disable" ] && st="DISABLED"
    [ -f "$d/remove" ] && st="REMOVE_PENDING"
    echo "--- $id ($st) ---"
    grep -E '^(id|name|version|description)=' "$d/module.prop" 2>/dev/null || true
  done
}

disable_nonessential() {
  : > "$MARKER"
  echo "Keeping: $KEEP_IDS"
  for d in /data/adb/modules/*; do
    [ -d "$d" ] || continue
    id=$(basename "$d")
    keep=0
    for k in $KEEP_IDS; do
      [ "$id" = "$k" ] && keep=1
    done
    if [ "$keep" -eq 1 ]; then
      echo "KEEP $id"
      continue
    fi
    if [ -f "$d/disable" ]; then
      echo "ALREADY_DISABLED $id"
      continue
    fi
    touch "$d/disable"
    echo "$id" >> "$MARKER"
    echo "DISABLED $id"
  done
  echo "Disabled list: $MARKER"
  cat "$MARKER" 2>/dev/null || true
}

restore_modules() {
  if [ ! -f "$MARKER" ]; then
    echo "No marker $MARKER — nothing to restore"
    return 0
  fi
  while read -r id; do
    [ -n "$id" ] || continue
    rm -f "/data/adb/modules/$id/disable"
    echo "RESTORED $id"
  done < "$MARKER"
  rm -f "$MARKER"
}

smoke_test() {
  echo "========== LOOP SMOKE =========="
  cat /sys/module/loop/parameters/max_loop 2>/dev/null || true
  echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
  IMG=/data/local/tmp/sparse-ab-modtest.img
  MP=/data/local/tmp/sparse-ab-modtest-mnt
  rm -f "$IMG" 2>/dev/null
  rmdir "$MP" 2>/dev/null || true
  truncate -s 64M "$IMG"
  mkfs.ext4 -F "$IMG" >/dev/null 2>&1
  mkdir -p "$MP"
  chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

  echo "--- mount -o loop ---"
  if mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1; then
    echo "RESULT mount_o_loop: SUCCESS"
    umount "$MP" 2>/dev/null || true
  else
    echo "RESULT mount_o_loop: FAILED"
  fi

  FREE=""
  for i in $(seq 48 63); do
    losetup /dev/block/loop$i 2>/dev/null && continue
    FREE=$i
    break
  done
  echo "first free loop 48-63: ${FREE:-none}"
  if [ -n "$FREE" ]; then
    losetup /dev/block/loop$FREE "$IMG" 2>&1
    if mount -t ext4 -o rw /dev/block/loop$FREE "$MP" 2>&1; then
      echo "RESULT explicit_losetup: SUCCESS"
      umount "$MP" 2>/dev/null || true
      losetup -d /dev/block/loop$FREE 2>/dev/null || true
    else
      echo "RESULT explicit_losetup: MOUNT_FAILED"
      losetup -d /dev/block/loop$FREE 2>/dev/null || true
    fi
  fi

  echo "--- CLI rootfs-img (3G test img if present) ---"
  TIMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
  DS=/data/local/Droidspaces/bin/droidspaces
  if [ -f "$TIMG" ] && [ -x "$DS" ]; then
    "$DS" --name=modtest-sparse --rootfs-img="$TIMG" --hostname=modtest-sparse \
      --net=none start 2>&1 | tail -8
    if "$DS" show 2>/dev/null | grep -q modtest-sparse; then
      echo "RESULT cli_rootfs_img: SUCCESS"
      "$DS" --name=modtest-sparse stop 2>/dev/null || true
    else
      echo "RESULT cli_rootfs_img: FAILED"
    fi
  else
    echo "SKIP cli_rootfs_img (no test img or droidspaces)"
  fi

  rm -f "$IMG" 2>/dev/null
  rmdir "$MP" 2>/dev/null || true
  echo "========== DONE SMOKE =========="
}

cmd="${1:-scan}"
case "$cmd" in
  scan) scan_modules ;;
  disable-nonessential) disable_nonessential ;;
  restore) restore_modules ;;
  smoke) smoke_test ;;
  *) echo "usage: $0 {scan|disable-nonessential|restore|smoke}"; exit 1 ;;
esac