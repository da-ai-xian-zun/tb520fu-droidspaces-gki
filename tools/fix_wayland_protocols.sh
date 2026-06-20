#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run bash -c '
set -e
VER=1.45
cd /tmp
if [ ! -d wayland-protocols-1.45 ]; then
  wget -q -O wp.tar.gz "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/archive/${VER}/wayland-protocols-${VER}.tar.gz"
  tar -xf wp.tar.gz
fi
cd wayland-protocols-${VER}
meson setup build --prefix=/usr
ninja -C build install
pkg-config --modversion wayland-protocols
' 2>&1