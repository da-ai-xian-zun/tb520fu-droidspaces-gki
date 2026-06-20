#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c '
for p in build-essential meson ninja-build pkg-config libwayland-dev libpixman-1-dev libxkbcommon-dev libinput-dev libevdev-dev libdrm-dev libudev-dev libseat-dev libcairo2-dev libjpeg-dev libwebp-dev libpam0g-dev libgles-dev libvulkan-dev glslang-tools libxcb-composite0-dev libxcb-shape0-dev libxcb-xfixes0-dev libxcursor-dev libxcb1-dev libpango1.0-dev libglib2.0-dev wayland-protocols libpng-dev libfontconfig-dev libfreetype-dev hwdata; do
  dpkg -s "$p" >/dev/null 2>&1 && echo "ok $p" || echo "MISSING $p"
done
' 2>&1