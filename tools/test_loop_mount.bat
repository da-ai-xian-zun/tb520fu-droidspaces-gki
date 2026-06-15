@echo off
adb wait-for-device
adb shell su -c "rm -f /data/local/tmp/test-loop.img"
adb shell su -c "truncate -s 64M /data/local/tmp/test-loop.img"
adb shell su -c "mkfs.ext4 -F /data/local/tmp/test-loop.img"
adb shell su -c "mkdir -p /data/local/tmp/test-loop-mnt"
adb shell su -c "chcon u:object_r:vold_data_file:s0 /data/local/tmp/test-loop.img"
echo === mount minimal ===
adb shell su -c "mount -t ext4 -o loop,rw /data/local/tmp/test-loop.img /data/local/tmp/test-loop-mnt"
echo mount exit=%errorlevel%
echo === mount app options ===
adb shell su -c "umount /data/local/tmp/test-loop-mnt" 2>nul
adb shell su -c "mount -t ext4 -o loop,rw,nodelalloc,noatime,nodiratime,init_itable=0 /data/local/tmp/test-loop.img /data/local/tmp/test-loop-mnt"
echo mount2 exit=%errorlevel%
adb shell su -c "mount | grep test-loop"
echo === dmesg avc ===
adb shell su -c "dmesg | tail -20"