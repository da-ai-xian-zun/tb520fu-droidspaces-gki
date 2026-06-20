#!/system/bin/sh
SOCK=/data/local/Droidspaces/Containers/debian13/rootfs/run/display_daemon.sock
DAEMON=/data/adb/modules/virtual-drm-daemon/display_daemon
pkill -f display_daemon 2>/dev/null
sleep 1
mkdir -p /data/local/Droidspaces/Containers/debian13/rootfs/run
chmod 1777 /data/local/Droidspaces/Containers/debian13/rootfs/run
rm -f "$SOCK"
"$DAEMON" "$SOCK" &
sleep 2
ls -la "$SOCK" 2>/dev/null || ls -la /data/local/Droidspaces/Containers/debian13/rootfs/run/
pgrep -a display_daemon