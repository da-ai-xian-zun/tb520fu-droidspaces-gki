#!/system/bin/sh
echo "=== host log ==="
tail -20 /data/local/tmp/anland-install-host.log 2>/dev/null || echo "no host log yet"
echo "=== container log ==="
tail -25 /data/local/Droidspaces/Containers/debian13/rootfs/var/log/anland-install.log 2>/dev/null || echo "no container log"
echo "=== procs ==="
ps -A 2>/dev/null | grep -iE 'apt|meson|ninja|weston|container_install|resume' | head -15
/data/local/Droidspaces/bin/droidspaces --name=debian13 run sh -c 'pgrep -a apt; pgrep -a meson; pgrep -a ninja' 2>/dev/null || true