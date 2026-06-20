#!/bin/sh
set -e

DS=/data/local/Droidspaces/bin/droidspaces
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs

echo "==> Disable KWin compositor (black screen fix)"
if [ -f "$ROOTFS/root/.config/kwinrc" ]; then
  sed -i 's/^Enabled=true/Enabled=false/' "$ROOTFS/root/.config/kwinrc"
  sed -i 's/^GLCore=true/GLCore=false/' "$ROOTFS/root/.config/kwinrc"
  grep -E '^Enabled=|^GLCore=|^Backend=' "$ROOTFS/root/.config/kwinrc" || true
fi

echo "==> Stop container"
$DS --name=debian13 stop 2>/dev/null || true
sleep 2

echo "==> Kill stale Termux:X11"
pkill -f 'termux-x11.*:5' 2>/dev/null || true
sleep 1

echo "==> Force-stop Termux:X11 app"
am force-stop com.termux.x11 2>/dev/null || true
sleep 1

echo "==> Start container"
$DS --name=debian13 start
sleep 5

echo "==> Restart Plasma inside container"
$DS --name=debian13 run systemctl restart de-autostart.service 2>/dev/null || true
sleep 12

echo "==> Check processes"
$DS --name=debian13 run pgrep -a kwin_x11 2>/dev/null || true
$DS --name=debian13 run pgrep -a plasmashell 2>/dev/null || true

echo "Done. Open Termux:X11 app on the tablet."