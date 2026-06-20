#!/system/bin/sh
# Read-only diagnostics for magic_mount_rs vs sparse/loop mount - DO NOT MODIFY ANYTHING

echo "========== magic_mount_rs config =========="
cat /data/adb/magic_mount/config.toml 2>&1
echo ""
echo "========== custom bind list =========="
if [ -f /data/adb/magic_mount/custom ]; then
  cat /data/adb/magic_mount/custom
else
  echo "(file not found)"
fi
echo ""
echo "========== mmrs module state =========="
ls -la /data/adb/modules/magic_mount_rs/ 2>&1
echo "--- module.prop ---"
cat /data/adb/modules/magic_mount_rs/module.prop 2>&1
echo ""
echo "========== all enabled KSU modules =========="
for d in /data/adb/modules/*; do
  [ -d "$d" ] || continue
  id=$(basename "$d")
  dis=""
  [ -f "$d/disable" ] && dis=" [DISABLED]"
  [ -f "$d/remove" ] && dis=" [REMOVE]"
  echo "--- $id$dis ---"
  grep -E '^(id|name|version)=' "$d/module.prop" 2>/dev/null
  [ -d "$d/system" ] && echo "  has system/ overlay"
done
echo ""
echo "========== loop pool =========="
cat /sys/module/loop/parameters/max_loop 2>&1
echo -n "loop devices: "
ls /dev/block/loop* 2>/dev/null | wc -l
echo -n "losetup bound: "
losetup -a 2>/dev/null | wc -l
echo ""
echo "========== Droidspaces paths =========="
ls -la /data/local/Droidspaces/ 2>&1 | head -20
ls -la /data/local/Droidspaces/Containers/ 2>&1 | head -10
echo ""
echo "========== mount entries touching Droidspaces/mnt/data =========="
mount 2>/dev/null | grep -iE 'droidspaces|/mnt/Droidspaces|magic_mount|/data/local/Droidspaces' || echo "(none)"
echo ""
echo "========== custom bind targets (if any) mounted? =========="
if [ -f /data/adb/magic_mount/custom ]; then
  grep '^bind ' /data/adb/magic_mount/custom 2>/dev/null | while read _ src tgt; do
    echo "bind: $src -> $tgt"
    mount 2>/dev/null | grep "$tgt" || echo "  (not in mount table)"
  done
else
  echo "(no custom file)"
fi
echo ""
echo "========== MagicMount recent log =========="
logcat -d -s MagicMount 2>/dev/null | tail -30
echo ""
echo "========== loop mount smoke test (64M, readonly check) =========="
IMG=/data/local/tmp/diag-loop-test.img
MP=/data/local/tmp/diag-loop-test-mnt
rm -f "$IMG" 2>/dev/null
truncate -s 64M "$IMG" 2>/dev/null
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
mkdir -p "$MP" 2>/dev/null
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null
echo "--- mount -o loop ---"
mount -t ext4 -o loop,rw "$IMG" "$MP" 2>&1
echo "exit=$?"
if mount | grep -q diag-loop-test-mnt; then
  echo "mount -o loop: SUCCESS"
  umount "$MP" 2>/dev/null
else
  echo "mount -o loop: FAILED"
fi
echo "--- explicit losetup ---"
FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
echo "first free loop in 48-63: ${FREE:-none}"
if [ -n "$FREE" ]; then
  losetup /dev/block/loop$FREE "$IMG" 2>&1
  mount -t ext4 -o rw /dev/block/loop$FREE "$MP" 2>&1
  echo "explicit mount exit=$?"
  mount | grep diag-loop-test-mnt || echo "explicit: not mounted"
  umount "$MP" 2>/dev/null
  losetup -d /dev/block/loop$FREE 2>/dev/null
fi
rm -f "$IMG" 2>/dev/null
rmdir "$MP" 2>/dev/null
echo ""
echo "========== DONE (read-only except temp test img cleaned) =========="