@echo off
adb wait-for-device
adb shell su -c "rm -f /data/local/tmp/test-loop.img"
adb shell su -c "truncate -s 64M /data/local/tmp/test-loop.img"
adb shell su -c "mkfs.ext4 -F /data/local/tmp/test-loop.img"
adb shell su -c "mkdir -p /data/local/tmp/test-loop-mnt"
adb shell su -c "chcon u:object_r:vold_data_file:s0 /data/local/tmp/test-loop.img"
echo === free loops ===
adb shell su -c "for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47; do losetup /dev/block/loop$i 2>/dev/null || echo free loop$i; done"
echo === losetup loop47 explicit ===
adb shell su -c "losetup /dev/block/loop47 /data/local/tmp/test-loop.img 2>&1"
echo === mount loop47 ===
adb shell su -c "mount -t ext4 -o rw /dev/block/loop47 /data/local/tmp/test-loop-mnt 2>&1"
adb shell su -c "mount | grep test-loop"
adb shell su -c "ulimit -n"