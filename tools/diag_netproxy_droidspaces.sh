#!/system/bin/sh
# Diagnose NetProxy + Droidspaces network interaction on the device.

DS=/data/local/Droidspaces/bin/droidspaces
TPROXY_CONF=/data/adb/modules/netproxy/config/tproxy/tproxy.conf
CLI=/data/adb/modules/netproxy/scripts/cli

echo "=== NetProxy service ==="
[ -x "$CLI" ] && "$CLI" service status 2>&1 || echo "cli missing"
[ -x "$CLI" ] && "$CLI" mode 2>&1 || true

echo "=== tproxy.conf (bypass related) ==="
[ -f "$TPROXY_CONF" ] && grep -E '^(OTHER_BYPASS|OTHER_PROXY|BYPASS_IPv4|DNS_HIJACK|PROXY_WIFI|WIFI_INTERFACE)=' "$TPROXY_CONF" \
  || echo "tproxy.conf not found"

echo "=== host interfaces / routes ==="
ip -4 link show | grep -E '^[0-9]+:|ds-br|wlan|rmnet' || true
ip -4 route show | head -10

echo "=== host DNS test (fake-ip = NetProxy DNS hijack) ==="
getent hosts deb.debian.org 2>/dev/null || nslookup deb.debian.org 2>/dev/null | head -5

echo "=== iptables tproxy hints ==="
iptables -t mangle -L PROXY_PREROUTING -n 2>/dev/null | head -8 || true
iptables -t mangle -L BYPASS_INTERFACE -n 2>/dev/null | head -8 || true

echo "=== droidspaces containers ==="
[ -x "$DS" ] && "$DS" show 2>&1 || echo "droidspaces missing"

for c in /data/local/Droidspaces/Containers/*/container.config; do
  [ -f "$c" ] || continue
  echo "--- $c ---"
  grep -E '^(name|net_mode|dns_servers)=' "$c" || true
done

NAME="${1:-debian13}"
if [ -x "$DS" ] && "$DS" status "$NAME" >/dev/null 2>&1; then
  echo "=== container $NAME network ==="
  "$DS" --name="$NAME" run sh -c '
    echo "resolv.conf:"; cat /etc/resolv.conf
    echo "routes:"; ip -4 route show
    echo "addrs:"; ip -4 addr show
    echo "dns test:"; getent hosts deb.debian.org 2>/dev/null || true
    ping -c1 -W2 1.1.1.1 2>&1 | tail -2
  ' 2>&1
fi