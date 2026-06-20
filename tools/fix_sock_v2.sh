#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs
MODDIR=/data/adb/modules/virtual-drm-daemon
SOCK_IN_CONTAINER=/var/lib/anland/display_daemon.sock
SOCK_HOST="$ROOTFS/var/lib/anland/display_daemon.sock"

mkdir -p "$ROOTFS/var/lib/anland"
chmod 1777 "$ROOTFS/var/lib/anland"

$DS --name=debian13 run sh -c 'mount | grep -E "on /var/lib |on /var/run "; ls -ld /var/lib/anland 2>/dev/null; mkdir -p /var/lib/anland' 2>&1

pkill -f display_daemon 2>/dev/null || true
sleep 1
rm -f "$SOCK_HOST"
"$MODDIR/display_daemon" "$SOCK_HOST" &
sleep 2
ls -la "$SOCK_HOST"

$DS --name=debian13 run sh -c "ls -la $SOCK_IN_CONTAINER; ln -sf $SOCK_IN_CONTAINER /run/display_daemon.sock; ls -la /run/display_daemon.sock" 2>&1

cat > "$MODDIR/service.sh" <<EOF
#!/system/bin/sh
MODDIR=\${0%/*}
SOCK=$SOCK_HOST
mkdir -p \$(dirname "\$SOCK")
chmod 1777 \$(dirname "\$SOCK") 2>/dev/null || true
rm -f "\$SOCK"
"\$MODDIR/display_daemon" "\$SOCK" &
EOF
chmod 755 "$MODDIR/service.sh"

$DS --name=debian13 run sh -c "sed -i 's|/run/display_daemon.sock|$SOCK_IN_CONTAINER|g; s|/var/run/anland/display_daemon.sock|$SOCK_IN_CONTAINER|g' /usr/local/bin/de-start; grep -E 'start_kde|SOCK' /usr/local/bin/de-start | head -3" 2>&1

echo "=== weston test ==="
$DS --name=debian13 run sh -c "su -l -w HOME,XDG_RUNTIME_DIR debian -c 'HOME=/home/debian XDG_RUNTIME_DIR=/run/user/1000 install -d -m0700 \$XDG_RUNTIME_DIR; /opt/weston-anland/start_kde_zink.sh $SOCK_IN_CONTAINER'" 2>&1 &
sleep 12
$DS --name=debian13 run sh -c 'pgrep -a weston; pgrep -a kwin; pgrep -a plasmashell' 2>&1