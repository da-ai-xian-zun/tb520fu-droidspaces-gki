#!/system/bin/sh
for slot in boot_a boot_b; do
  dev="/dev/block/bootdevice/by-name/$slot"
  echo "=== $slot ==="
  ls -l "$dev"
  blockdev --getsize64 "$dev" 2>/dev/null
  md5sum "$dev" 2>/dev/null
  strings "$dev" 2>/dev/null | grep -m1 'Linux version'
  strings "$dev" 2>/dev/null | grep -m1 '6\.6\.[0-9][0-9]*'
  strings "$dev" 2>/dev/null | grep -m1 'android15'
  echo
done
echo "=== current ==="
getprop ro.boot.slot_suffix
uname -r