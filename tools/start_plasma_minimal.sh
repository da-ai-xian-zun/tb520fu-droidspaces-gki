#!/system/bin/sh
MODDIR=/data/adb/modules/virtual-drm-daemon
SOCK=/data/local/Droidspaces/Containers/debian13/rootfs/var/lib/anland/display_daemon.sock
DS=/data/local/Droidspaces/bin/droidspaces

am start -n com.virtual_drm.consumer/.MainActivity
sleep 6
pkill -f display_daemon; sleep 1
rm -f "$SOCK"
"$MODDIR/display_daemon" "$SOCK" &
sleep 3

$DS --name=debian13 run bash -lc '
export SOCK=/var/lib/anland/display_daemon.sock
export LD_LIBRARY_PATH=/opt/weston-anland/lib/aarch64-linux-gnu:/opt/weston-anland/lib/aarch64-linux-gnu/libweston-16:/opt/weston-anland/lib/aarch64-linux-gnu/weston
export XDG_RUNTIME_DIR=/run/user/1000
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
/opt/weston-anland/bin/weston -Banland-backend.so --disp-sock=$SOCK --shell=kiosk-shell.so --no-config &
sleep 5
pgrep -a weston
WAYLAND_DISPLAY=wayland-1 startplasma-wayland &
sleep 15
pgrep -af kwin; pgrep -af plasmashell
' 2>&1