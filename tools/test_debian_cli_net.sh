#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian-cli run sh -c '
echo "=== resolv.conf ==="
cat /etc/resolv.conf
echo "=== addr/route ==="
ip -4 addr show
ip -4 route show
echo "=== dns ==="
getent hosts deb.debian.org 2>&1 || true
getent hosts github.com 2>&1 || true
echo "=== ping ==="
ping -c1 -W3 1.1.1.1 2>&1
ping -c1 -W5 deb.debian.org 2>&1 | tail -3
'