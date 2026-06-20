#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs
CONF=/data/local/Droidspaces/Containers/debian13/container.config

# Kill stuck apt from failed install attempt
$DS --name=$NAME run sh -c 'pkill -9 apt-get apt dpkg 2>/dev/null; dpkg --configure -a 2>/dev/null || true' 2>/dev/null || true

echo "==> restore IPv4 DNS"
printf 'nameserver 192.168.5.1\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ROOTFS/run/resolvconf/resolv.conf" 2>/dev/null || true
$DS --name=$NAME run sh -c 'mkdir -p /run/resolvconf; printf "nameserver 192.168.5.1\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /run/resolvconf/resolv.conf; cat /etc/resolv.conf' 2>&1

sed -i 's/^dns_servers=.*/dns_servers=192.168.5.1,1.1.1.1/' "$CONF" 2>/dev/null || echo 'dns_servers=192.168.5.1,1.1.1.1' >> "$CONF"

echo "==> remove stale ipv6 hosts bypass (optional)"
# keep hosts bypass harmless; apt should work with normal DNS now

echo "==> network test"
$DS --name=$NAME run sh -c 'ping -c1 -W3 192.168.5.1; ping -c1 -W3 1.1.1.1; getent hosts deb.debian.org | head -2; apt-get update -qq 2>&1 | tail -4' 2>&1

echo "==> install build deps only"
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
  libpng-dev libfontconfig-dev libfreetype-dev hwdata 2>&1 | tail -15

echo "==> restart full install if deps ok"
cp /data/local/tmp/container_install_anland.sh "$ROOTFS/usr/local/bin/container_install_anland.sh"
chmod 755 "$ROOTFS/usr/local/bin/container_install_anland.sh"
nohup $DS --name=$NAME run bash /usr/local/bin/container_install_anland.sh >> /data/local/tmp/anland-install-host.log 2>&1 &
echo started