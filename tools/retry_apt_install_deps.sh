#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

$DS --name=$NAME run sh -c '
ip route show | grep -q "^default" || ip route add default via 192.168.5.1 dev wlan0
apt-get update 2>&1 | tail -10
apt-get install -y build-essential meson ninja-build pkg-config \
  libwayland-dev libpixman-1-dev libxkbcommon-dev \
  libinput-dev libevdev-dev libdrm-dev \
  libudev-dev libseat-dev libcairo2-dev \
  libjpeg-dev libwebp-dev libpam0g-dev \
  libgles-dev libvulkan-dev glslang-tools \
  libxcb-composite0-dev libxcb-shape0-dev libxcb-xfixes0-dev \
  libxcursor-dev libxcb1-dev libpango1.0-dev libglib2.0-dev \
  libwayland-cursor0 wayland-protocols libwayland-bin \
  libpng-dev libfontconfig-dev libfreetype-dev hwdata 2>&1 | tail -15
command -v meson && command -v ninja && echo DEPS_OK
' 2>&1