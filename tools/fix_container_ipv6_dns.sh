#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs

# Use router IPv6 DNS from Android connectivity stack
cat > "$ROOTFS/etc/resolv.conf" <<'EOF'
nameserver 2408:8256:528b:57f::1
nameserver 2408:8256:528b:57f::1%wlan0
options inet6
EOF

echo "=== resolv.conf ==="
cat "$ROOTFS/etc/resolv.conf"

echo "=== ipv6 test in container ==="
$DS --name=$NAME run sh -c 'cat /etc/resolv.conf; ping6 -c1 -W3 2408:8256:528b:57f::1; getent ahostsv6 deb.debian.org | head -3; apt-get update -qq 2>&1 | tail -5' 2>&1