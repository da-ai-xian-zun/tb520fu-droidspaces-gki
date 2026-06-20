#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
$DS --name=debian13 run sh -c 'apt-cache search plasma-wayland | head -15; apt-cache search startplasma | head -10; command -v startplasma-wayland; dpkg -l | grep -iE "wayland|kwin" | head -20' 2>&1