#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13
CONF=/data/local/Droidspaces/Containers/debian13/container.config

echo "==> patch live resolv.conf"
$DS --name=$NAME run sh -c 'mkdir -p /run/resolvconf; printf "nameserver 2408:8256:528b:57f::1\noptions inet6\n" > /run/resolvconf/resolv.conf; cat /etc/resolv.conf; getent ahostsv6 deb.debian.org | head -3' 2>&1

echo "==> persist dns in container.config"
if grep -q '^dns_servers=' "$CONF" 2>/dev/null; then
  sed -i 's/^dns_servers=.*/dns_servers=2408:8256:528b:57f::1/' "$CONF"
else
  echo 'dns_servers=2408:8256:528b:57f::1' >> "$CONF"
fi
grep dns "$CONF" || true

echo "==> apt update test"
$DS --name=$NAME run apt-get update -qq 2>&1 | tail -8