#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

$DS --name=$NAME run sh -c '
set -e
# Remove IPv6-only hosts override so apt prefers IPv4
sed -i "/anland-ipv6-bypass/,+4d" /etc/hosts 2>/dev/null || true

mkdir -p /run/resolvconf
printf "nameserver 192.168.5.1\nnameserver 1.1.1.1\n" > /run/resolvconf/resolv.conf

ip route show | grep -q "^default" || ip route add default via 192.168.5.1 dev wlan0 2>/dev/null || true

echo "=== routes ==="
ip route show
echo "=== dns resolve ==="
getent hosts deb.debian.org | head -3
echo "=== ping ==="
ping -c1 -W3 1.1.1.1 || true

rm -rf /var/lib/apt/lists/*
apt-get update 2>&1 | tail -6
' 2>&1

echo "==> install build deps"
$DS --name=$NAME run apt-get install -y -qq \
  build-essential meson ninja-build pkg-config \
  libwayland-dev libpixman-1-dev libxkbcommon-dev \
  libinput-dev libevdev-dev libdrm-dev \
  libudev-dev libseat-dev libcairo2-dev \
  libjpeg-dev libwebp-dev libpam0g-dev \
  libgles-dev libvulkan-dev glslang-tools \
  libxcb-composite0-dev libxcb-shape0-dev libxcb-xfixes0-dev \
  libxcursor-dev libxcb1-dev libpango1.0-dev libglib2.0-dev \
  libwayland-cursor0 wayland-protocols libwayland-bin \
  libpng-dev libfontconfig-dev libfreetype-dev hwdata 2>&1 | tail -10