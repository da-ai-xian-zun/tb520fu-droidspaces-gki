#!/system/bin/sh
# Start (or reconfigure) a CLI-only Droidspaces container on NAT network.
# Prerequisite: run tools/netproxy_bypass_droidspaces.sh on the host first.
#
# Usage on device (root shell):
#   sh /data/local/tmp/setup_debian_cli_nat.sh
# Optional env:
#   ROOTFS_SRC=/data/local/Droidspaces/Containers/debian13/rootfs

set -e

DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian-cli
BASE=/data/local/Droidspaces/Containers
ROOTFS_SRC="${ROOTFS_SRC:-$BASE/debian13/rootfs}"
ROOTFS_DST="$BASE/$NAME/rootfs"
GW=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $3}')
[ -z "$GW" ] && GW=192.168.1.1

if [ ! -x "$DS" ]; then
  echo "ERROR: droidspaces not found at $DS"
  exit 1
fi

echo "host gateway=$GW"

if [ ! -d "$ROOTFS_DST" ]; then
  if [ ! -d "$ROOTFS_SRC" ]; then
    echo "ERROR: no rootfs at $ROOTFS_SRC — set ROOTFS_SRC or install a Debian rootfs first"
    exit 1
  fi
  echo "Cloning rootfs from $ROOTFS_SRC -> $ROOTFS_DST (one-time, may take a while)..."
  mkdir -p "$BASE/$NAME"
  cp -a "$ROOTFS_SRC" "$ROOTFS_DST"
fi

if "$DS" status "$NAME" >/dev/null 2>&1; then
  echo "Stopping existing $NAME..."
  "$DS" --name="$NAME" stop 2>/dev/null || true
  sleep 1
fi

echo "Starting $NAME (NAT, no GUI)..."
"$DS" \
  --name="$NAME" \
  --rootfs="$ROOTFS_DST" \
  --hostname="$NAME" \
  --net=nat \
  --port=2222:22 \
  --dns="$GW,1.1.1.1,8.8.8.8" \
  start 2>&1

sleep 2

CONF="$BASE/$NAME/container.config"
if [ -f "$CONF" ]; then
  for kv in \
    "net_mode=nat" \
    "enable_termux_x11=0" \
    "enable_virgl=0" \
    "enable_pulseaudio=0" \
    "enable_gpu_mode=0" \
    "dns_servers=${GW},1.1.1.1,8.8.8.8"; do
    key=${kv%%=*}
    val=${kv#*=}
    if grep -q "^${key}=" "$CONF"; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$CONF"
    else
      echo "${key}=${val}" >> "$CONF"
    fi
  done
fi

echo "=== post-start check ==="
ip link show ds-br0 2>/dev/null || echo "ds-br0 not visible yet"
"$DS" --name="$NAME" run sh -c '
  echo "--- resolv.conf ---"
  cat /etc/resolv.conf
  echo "--- network ---"
  ip -4 addr show
  ip -4 route show
  echo "--- dns (should NOT be 198.18.x.x) ---"
  getent hosts deb.debian.org || true
  ping -c1 -W3 1.1.1.1
' 2>&1

echo ""
echo "Next inside $NAME:"
echo "  1. mask systemd-networkd if it overwrites DNS"
echo "  2. apt update && apt install -y git curl tmux"
echo "  3. EasyTier + sing-box explicit proxy (no TUN) for home Gitea"
echo "SSH: adb forward tcp:2222 tcp:2222 && ssh -p 2222 debian@127.0.0.1"