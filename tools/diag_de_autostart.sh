#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
echo "=== de-autostart status ==="
systemctl status de-autostart.service --no-pager 2>&1 | head -20
echo "=== journal ==="
journalctl -u de-autostart.service -n 40 --no-pager 2>&1
echo "=== socket ==="
ls -la /run/display_daemon.sock
echo "=== manual test (5s) ==="
/opt/weston-anland/start_kde_zink.sh /run/display_daemon.sock &
sleep 8
pgrep -a weston || echo no weston
pgrep -a kwin || echo no kwin
' 2>&1