#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs
HOSTS="$ROOTFS/etc/hosts"

# Real Fastly IPv6 for deb.debian.org (bypass Android 198.18.0.13 DNS proxy)
BLOCK='# anland-ipv6-bypass'
if ! grep -q "$BLOCK" "$HOSTS" 2>/dev/null; then
  cat >> "$HOSTS" <<'EOF'
# anland-ipv6-bypass
2a04:4e42:600::644 deb.debian.org debian.map.fastlydns.net
2a04:4e42::644 deb.debian.org debian.map.fastlydns.net
2a04:4e42:200::644 deb.debian.org debian.map.fastlydns.net
2a04:4e42:400::644 deb.debian.org debian.map.fastlydns.net
EOF
fi

echo "=== hosts tail ==="
tail -8 "$HOSTS"

echo "=== apt update test ==="
$DS --name=$NAME run sh -c 'getent ahostsv6 deb.debian.org | head -3; apt-get update -qq 2>&1 | tail -6' 2>&1