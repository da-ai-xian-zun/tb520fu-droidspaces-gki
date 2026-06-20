#!/system/bin/sh
# Configure NetProxy-Magisk to bypass Droidspaces NAT bridge traffic.
# Run on device: adb push + adb shell su -c sh /data/local/tmp/netproxy_bypass_droidspaces.sh
#
# Docs: https://github.com/Fanju6/NetProxy-Magisk
# Config: /data/adb/modules/netproxy/config/tproxy/tproxy.conf

set -e

TPROXY_CONF=/data/adb/modules/netproxy/config/tproxy/tproxy.conf
CLI=/data/adb/modules/netproxy/scripts/cli
DS_NET=172.28.0.0/16
DS_IF=ds-br0

if [ ! -f "$TPROXY_CONF" ]; then
  echo "ERROR: NetProxy not installed or tproxy.conf missing: $TPROXY_CONF"
  exit 1
fi

echo "=== before ==="
grep -E '^(OTHER_BYPASS_INTERFACES|BYPASS_IPv4_LIST)=' "$TPROXY_CONF" || true

cp -a "$TPROXY_CONF" "${TPROXY_CONF}.bak.$(date +%Y%m%d%H%M%S)"

# Interface bypass: traffic entering/leaving ds-br0 skips transparent proxy + DNS hijack on wlan0.
if grep -q '^OTHER_BYPASS_INTERFACES=' "$TPROXY_CONF"; then
  cur=$(grep '^OTHER_BYPASS_INTERFACES=' "$TPROXY_CONF" | cut -d= -f2- | tr -d '"')
  case " $cur " in
    *" $DS_IF "*) ;;
    *)
      if [ -n "$cur" ]; then
        new="$cur $DS_IF"
      else
        new="$DS_IF"
      fi
      sed -i "s|^OTHER_BYPASS_INTERFACES=.*|OTHER_BYPASS_INTERFACES=\"$new\"|" "$TPROXY_CONF"
      ;;
  esac
else
  echo "OTHER_BYPASS_INTERFACES=\"$DS_IF\"" >> "$TPROXY_CONF"
fi

# Explicit subnet (default BYPASS list already includes 172.16.0.0/12, but keep explicit for safety).
if grep -q '^BYPASS_IPv4_LIST=' "$TPROXY_CONF"; then
  cur=$(grep '^BYPASS_IPv4_LIST=' "$TPROXY_CONF" | cut -d= -f2- | tr -d '"')
  case " $cur " in
    *" $DS_NET "*) ;;
    *)
      sed -i "s|^BYPASS_IPv4_LIST=.*|BYPASS_IPv4_LIST=\"$cur $DS_NET\"|" "$TPROXY_CONF"
      ;;
  esac
fi

echo "=== after ==="
grep -E '^(OTHER_BYPASS_INTERFACES|BYPASS_IPv4_LIST)=' "$TPROXY_CONF" || true

if [ -x "$CLI" ]; then
  echo "=== reload NetProxy tproxy ==="
  "$CLI" tproxy reload 2>/dev/null || "$CLI" service restart
  "$CLI" service status 2>/dev/null || true
else
  echo "WARN: cli not found; reboot or restart NetProxy service manually"
fi

echo "=== host bridge check ==="
ip link show "$DS_IF" 2>/dev/null || echo "(no $DS_IF yet — start a NAT container first)"