#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13
CONF=/data/local/Droidspaces/Containers/debian13/container.config
GW=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $3}')
[ -z "$GW" ] && GW=192.168.1.1

echo "host gw=$GW ip=$(ip -4 addr show wlan0 | awk '/inet / {print $2}')"

# update persisted dns for next container start
if grep -q '^dns_servers=' "$CONF" 2>/dev/null; then
  sed -i "s/^dns_servers=.*/dns_servers=${GW},1.1.1.1,8.8.8.8/" "$CONF"
else
  echo "dns_servers=${GW},1.1.1.1,8.8.8.8" >> "$CONF"
fi

$DS --name=$NAME run sh -c "
set -e
sed -i '/anland-ipv6-bypass/,+4d' /etc/hosts
grep -q anland-ipv4-bypass /etc/hosts || cat >> /etc/hosts <<'EOF'
# anland-ipv4-bypass
151.101.130.132 deb.debian.org debian.map.fastlydns.net
151.101.66.132 deb.debian.org debian.map.fastlydns.net
151.101.2.132 deb.debian.org debian.map.fastlydns.net
151.101.194.132 deb.debian.org debian.map.fastlydns.net
EOF
mkdir -p /run/resolvconf /etc/apt/apt.conf.d
printf 'nameserver ${GW}\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /run/resolvconf/resolv.conf
echo 'Acquire::ForceIPv4 \"true\";' > /etc/apt/apt.conf.d/99force-ipv4
echo 'Acquire::Retries \"5\";' >> /etc/apt/apt.conf.d/99force-ipv4
cat /etc/resolv.conf
getent hosts deb.debian.org | head -3
ping -c1 -W3 1.1.1.1
rm -rf /var/lib/apt/lists/*
apt-get update 2>&1 | tail -6
" 2>&1