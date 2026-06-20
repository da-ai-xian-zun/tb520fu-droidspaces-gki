#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

$DS --name=$NAME run sh -c '
set -x
sed -i "/anland-ipv6-bypass/,+4d" /etc/hosts 2>/dev/null || true
grep -q anland-ipv4-bypass /etc/hosts || cat >> /etc/hosts <<EOF
# anland-ipv4-bypass
151.101.130.132 deb.debian.org debian.map.fastlydns.net
151.101.66.132 deb.debian.org debian.map.fastlydns.net
151.101.2.132 deb.debian.org debian.map.fastlydns.net
151.101.194.132 deb.debian.org debian.map.fastlydns.net
EOF

ip route show | grep -q "^default" || ip route add default via 192.168.5.1 dev wlan0

getent hosts deb.debian.org | head -3
curl -I --max-time 15 http://deb.debian.org/debian/dists/trixie/InRelease 2>&1 | head -5

rm -rf /var/lib/apt/lists/*
apt-get update 2>&1 | tail -8
' 2>&1