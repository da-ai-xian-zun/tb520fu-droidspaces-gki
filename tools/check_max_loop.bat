@echo off
adb wait-for-device
adb shell su -c "cat /sys/module/loop/parameters/max_loop"
adb shell su -c "cat /sys/module/loop/parameters/max_part"
adb shell su -c "ls /dev/block/loop* | wc -l"
adb shell su -c "losetup -a | wc -l"