#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
echo "=== routes ==="
ip -6 route show
echo "=== ping6 debian ==="
ping6 -c2 -W3 2a04:4e42:600::644 2>&1
echo "=== curl http ==="
curl -6 -I --max-time 15 http://deb.debian.org/debian/dists/trixie/InRelease 2>&1 | head -8
echo "=== curl https ==="
curl -6 -I --max-time 15 https://deb.debian.org/debian/dists/trixie/InRelease 2>&1 | head -8
' 2>&1