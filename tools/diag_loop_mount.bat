@echo off
adb wait-for-device
echo === loop devices ===
adb shell su -c "ls -la /dev/loop-control /dev/block/loop-control 2>&1"
adb shell su -c "ls /dev/block/loop* 2>&1 | head -5"
echo === proc filesystems loop ===
adb shell su -c "cat /proc/filesystems | grep loop"
echo === dmesg tail ===
adb shell su -c "dmesg | tail -30"
echo === DONE ===