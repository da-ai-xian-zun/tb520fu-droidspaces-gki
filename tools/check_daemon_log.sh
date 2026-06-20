#!/system/bin/sh
echo "=== daemon procs ==="
pgrep -a display_daemon || echo none
echo "=== sockets ==="
ls -la /data/local/tmp/display_daemon.sock
ls -la /data/local/Droidspaces/Containers/debian13/rootfs/var/lib/anland/display_daemon.sock
echo "=== consumer ==="
dumpsys activity activities 2>/dev/null | grep -i virtual_drm | head -3 || true
echo "=== restart consumer to trigger reconnect ==="
am force-stop com.virtual_drm.consumer 2>/dev/null || true
sleep 1
am start -n com.virtual_drm.consumer/.MainActivity
sleep 5
pgrep -a display_daemon