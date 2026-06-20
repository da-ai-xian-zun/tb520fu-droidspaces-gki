#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs
SOCK_HOST=$ROOTFS/run/display_daemon.sock
MODDIR=/data/adb/modules/virtual-drm-daemon

echo "=== host rootfs sock ==="
ls -la "$SOCK_HOST" 2>/dev/null || echo missing

echo "=== container /run ==="
$DS --name=debian13 run sh -c 'mount | grep " on /run "; ls -la /run/ | head -15; ls -la /run/display_daemon.sock 2>/dev/null || echo no sock in container' 2>&1

echo "=== restart daemon into live container /run via nsenter ==="
PID=$($DS pid debian13 2>/dev/null | awk '{print $NF}')
echo "container pid=$PID"
pkill -f display_daemon 2>/dev/null || true
sleep 1

# write socket where container init can see it: bind mount host path if needed
mkdir -p "$ROOTFS/run"
chmod 1777 "$ROOTFS/run"
rm -f "$SOCK_HOST"
"$MODDIR/display_daemon" "$SOCK_HOST" &
sleep 2
ls -la "$SOCK_HOST"

# if container /run is tmpfs, copy/bind sock path via droidspaces run mount
$DS --name=debian13 run sh -c '
if [ ! -S /run/display_daemon.sock ]; then
  # try symlink from a persistent path
  mkdir -p /var/run/anland
  if [ -S /var/run/anland/display_daemon.sock ]; then
    ln -sf /var/run/anland/display_daemon.sock /run/display_daemon.sock
  fi
fi
ls -la /run/display_daemon.sock 2>/dev/null || ls -la /run/ | head -8
' 2>&1

echo "=== use persistent sock path /var/run/anland ==="
mkdir -p "$ROOTFS/var/run/anland"
chmod 1777 "$ROOTFS/var/run/anland"
rm -f "$ROOTFS/var/run/anland/display_daemon.sock" "$SOCK_HOST"
pkill -f display_daemon 2>/dev/null || true
sleep 1
"$MODDIR/display_daemon" "$ROOTFS/var/run/anland/display_daemon.sock" &
sleep 2
ls -la "$ROOTFS/var/run/anland/display_daemon.sock"

$DS --name=debian13 run sh -c '
ls -la /var/run/anland/display_daemon.sock
ln -sf /var/run/anland/display_daemon.sock /run/display_daemon.sock 2>/dev/null || true
ls -la /run/display_daemon.sock
' 2>&1

# patch service.sh for boot
cat > "$MODDIR/service.sh" <<EOF
#!/system/bin/sh
MODDIR=\${0%/*}
SOCK=$ROOTFS/var/run/anland/display_daemon.sock
mkdir -p \$(dirname "\$SOCK")
chmod 1777 \$(dirname "\$SOCK") 2>/dev/null || true
rm -f "\$SOCK"
"\$MODDIR/display_daemon" "\$SOCK" &
EOF
chmod 755 "$MODDIR/service.sh"

# patch de-start to use persistent sock + symlink
$DS --name=debian13 run sh -c "sed -i 's|/run/display_daemon.sock|/var/run/anland/display_daemon.sock|g' /usr/local/bin/de-start; grep SOCK= /usr/local/bin/de-start | head -1" 2>&1

echo "=== test weston ==="
$DS --name=debian13 run sh -c 'su -l debian -c "/opt/weston-anland/start_kde_zink.sh /var/run/anland/display_daemon.sock" &' 2>&1
sleep 10
$DS --name=debian13 run sh -c 'pgrep -a weston; pgrep -a kwin' 2>&1