#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
MODDIR=/data/adb/modules/virtual-drm-daemon
SOCK_HOST=/data/local/Droidspaces/Containers/debian13/rootfs/var/lib/anland/display_daemon.sock

# Order A: consumer first, then daemon, then weston
am force-stop com.virtual_drm.consumer 2>/dev/null
pkill -f display_daemon 2>/dev/null
sleep 1
am start -n com.virtual_drm.consumer/.MainActivity
sleep 8
rm -f "$SOCK_HOST"
"$MODDIR/display_daemon" "$SOCK_HOST" &
sleep 3
$DS --name=debian13 run /opt/weston-anland/bin/weston -Banland-backend.so --disp-sock=/var/lib/anland/display_daemon.sock --shell=kiosk-shell.so --no-config 2>&1 &
sleep 6
$DS --name=debian13 run pgrep -a weston 2>&1

# Order B: daemon first, consumer, wait longer, weston
pkill -f display_daemon 2>/dev/null
pkill weston 2>/dev/null
sleep 2
rm -f "$SOCK_HOST"
"$MODDIR/display_daemon" "$SOCK_HOST" &
sleep 2
am start -n com.virtual_drm.consumer/.MainActivity
sleep 10
$DS --name=debian13 run /opt/weston-anland/bin/weston -Banland-backend.so --disp-sock=/var/lib/anland/display_daemon.sock --shell=kiosk-shell.so --no-config 2>&1 &
sleep 6
$DS --name=debian13 run pgrep -a weston 2>&1