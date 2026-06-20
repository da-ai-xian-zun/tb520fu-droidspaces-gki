#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

echo "=== host network ==="
ip route 2>/dev/null | head -5
ip -4 addr show wlan0 2>/dev/null | head -3
getent hosts deb.debian.org 2>/dev/null || ping -c1 -W2 1.1.1.1 2>&1 | head -2

echo "=== container network ==="
$DS --name=$NAME run sh -c 'ip route; ip -4 addr; ip link; cat /proc/net/route | head -5' 2>&1

echo "=== container.config full ==="
cat /data/local/Droidspaces/Containers/debian13/container.config 2>/dev/null