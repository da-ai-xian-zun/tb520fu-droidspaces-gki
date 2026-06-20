#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
MODDIR=/data/adb/modules/virtual-drm-daemon
SOCK_HOST=/data/local/Droidspaces/Containers/debian13/rootfs/var/lib/anland/display_daemon.sock

am start -n com.virtual_drm.consumer/.MainActivity 2>/dev/null
sleep 5
pkill -f display_daemon 2>/dev/null; sleep 1
rm -f "$SOCK_HOST"
"$MODDIR/display_daemon" "$SOCK_HOST" &
sleep 3

$DS --name=debian13 run bash -c '
pkill -f start_kde 2>/dev/null || true
pkill weston 2>/dev/null || true
chmod 777 /var/lib/anland/display_daemon.sock
nohup /usr/local/bin/de-start >/tmp/de-start.log 2>&1 &
sleep 40
pgrep -af weston || true
pgrep -af kwin || true
pgrep -af plasmashell || true
tail -20 /tmp/de-start.log 2>/dev/null || true
' 2>&1