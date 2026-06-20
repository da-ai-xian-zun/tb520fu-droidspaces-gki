#!/system/bin/sh
CLI=/data/adb/modules/netproxy/scripts/cli
DS=/data/local/Droidspaces/bin/droidspaces
TPROXY=/data/adb/modules/netproxy/config/tproxy/tproxy.conf

echo "=== NetProxy status ==="
"$CLI" service status 2>&1

echo "=== tproxy bypass config ==="
grep -E '^(OTHER_BYPASS_INTERFACES|BYPASS_IPv4_LIST|DNS_HIJACK_ENABLE)=' "$TPROXY" 2>/dev/null || true

echo "=== ds-br0 ==="
ip -4 link show ds-br0 2>/dev/null || echo "(ds-br0 not up yet)"

echo "=== iptables BYPASS_INTERFACE ==="
iptables -t mangle -L BYPASS_INTERFACE -n 2>/dev/null | grep -E 'ds-br0|Chain' || true

echo "=== host DNS (ping) ==="
ping -c1 -W3 github.com 2>&1 | head -2

echo "=== start debian-cli if needed ==="
if ! "$DS" status debian-cli >/dev/null 2>&1; then
  "$DS" --name=debian-cli start 2>&1 | tail -8
  sleep 3
fi

echo "=== debian-cli status ==="
"$DS" show 2>&1

echo "=== container DNS ==="
"$DS" --name=debian-cli run getent hosts github.com 2>&1 || true
"$DS" --name=debian-cli run ping -c1 -W3 1.1.1.1 2>&1 | tail -3