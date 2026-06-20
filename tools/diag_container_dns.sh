#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

echo "=== resolv.conf in rootfs ==="
cat /data/local/Droidspaces/Containers/debian13/rootfs/etc/resolv.conf 2>/dev/null

echo "=== container network test ==="
$DS --name=$NAME run sh -c 'cat /etc/resolv.conf; getent hosts deb.debian.org; ping -c1 -W2 1.1.1.1; ping -c1 -W2 deb.debian.org' 2>&1

echo "=== container.config ==="
cat /data/local/Droidspaces/Containers/debian13/container.config 2>/dev/null | grep -iE 'dns|net' || true