#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs

echo "=== rootfs etc ==="
ls -la "$ROOTFS/etc/resolv.conf" 2>/dev/null || ls -la "$ROOTFS/etc/" | grep resolv
ls -la "$ROOTFS/run/resolv.conf" 2>/dev/null || true

echo "=== live container ==="
$DS --name=debian13 run sh -c 'ls -la /etc/resolv.conf; cat /etc/resolv.conf; ls -la /run/droidspaces* 2>/dev/null; getent ahostsv6 deb.debian.org' 2>&1

echo "=== env file ==="
cat /data/local/Droidspaces/Containers/debian13/.env 2>/dev/null