#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

for DNS in '2001:4860:4860::8888' '2606:4700:4700::1111' '2408:8256:528b:57f::1'; do
  echo "=== try DNS $DNS ==="
  $DS --name=$NAME run sh -c "printf 'nameserver $DNS\noptions inet6\n' > /run/resolvconf/resolv.conf; getent ahostsv6 deb.debian.org 2>&1 | head -5" 2>&1
done

echo "=== sources.list ==="
$DS --name=$NAME run sh -c 'cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null' 2>&1

echo "=== curl ipv6 test ==="
$DS --name=$NAME run sh -c 'command -v curl >/dev/null && curl -6 -I --max-time 10 http://deb.debian.org/debian/dists/trixie/InRelease 2>&1 | head -5' 2>&1