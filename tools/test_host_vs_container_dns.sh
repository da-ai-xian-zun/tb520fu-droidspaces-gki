#!/system/bin/sh
CLI=/data/adb/modules/netproxy/scripts/cli
DS=/data/local/Droidspaces/bin/droidspaces

echo "=== NetProxy status ==="
"$CLI" service status 2>&1 | head -8

echo "=== host DNS (expect 198.18.x.x when proxy ON) ==="
getent hosts github.com 2>&1 || true
getent hosts deb.debian.org 2>&1 | head -2 || true

echo "=== iptables BYPASS_INTERFACE (ds-br0) ==="
iptables -t mangle -L BYPASS_INTERFACE -n -v 2>/dev/null | head -10 || true

echo "=== debian-cli DNS (expect real IP, NOT 198.18.x.x) ==="
"$DS" --name=debian-cli run getent hosts github.com 2>&1 || true