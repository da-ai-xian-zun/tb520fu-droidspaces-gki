@echo off
adb wait-for-device
echo === CONFIG SYSVIPC ===
adb shell su -c "zcat /proc/config.gz" | findstr /C:CONFIG_SYSVIPC
echo === CONFIG PID_NS ===
adb shell su -c "zcat /proc/config.gz" | findstr /C:CONFIG_PID_NS
echo === CONFIG IPC_NS ===
adb shell su -c "zcat /proc/config.gz" | findstr /C:CONFIG_IPC_NS
echo === CONFIG POSIX_MQUEUE ===
adb shell su -c "zcat /proc/config.gz" | findstr /C:CONFIG_POSIX_MQUEUE
echo === DONE ===