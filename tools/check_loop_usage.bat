@echo off
adb wait-for-device
echo === loop device count ===
adb shell su -c "ls /dev/block/loop* | wc -l"
echo === losetup -a ===
adb shell su -c "losetup -a" 2>&1
echo === mount loop entries ===
adb shell su -c "mount | grep loop" 2>&1
echo === loop.max_part cmdline ===
adb shell su -c "cat /proc/cmdline" 2>&1 | findstr loop