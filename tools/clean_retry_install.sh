#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
pkill -9 apt-get apt dpkg 2>/dev/null || true
sleep 2
dpkg --configure -a 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
echo locks cleared
apt-get install -y -qq build-essential meson ninja-build pkg-config \
  libwayland-dev libpixman-1-dev libxkbcommon-dev libinput-dev libevdev-dev libdrm-dev \
  libudev-dev libseat-dev libcairo2-dev libjpeg-dev libwebp-dev libpam0g-dev \
  libgles-dev libvulkan-dev glslang-tools libxcb-composite0-dev libxcb-shape0-dev \
  libxcb-xfixes0-dev libxcursor-dev libxcb1-dev libpango1.0-dev libglib2.0-dev \
  libwayland-cursor0 wayland-protocols libwayland-bin libpng-dev libfontconfig-dev \
  libfreetype-dev hwdata wget ca-certificates 2>&1 | tail -8
command -v meson && command -v ninja && echo DEPS_OK
' 2>&1