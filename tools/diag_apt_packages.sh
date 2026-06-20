#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian13

$DS --name=$NAME run sh -c '
apt-get update -qq 2>&1 | tail -5
echo "=== plasma-wayland ==="
apt-cache search plasma-workspace-wayland | head -5
apt-cache search plasma.*wayland | head -10
dpkg -l | grep -i plasma-workspace | head -10
echo "=== libxcb-xfixes ==="
apt-cache search libxcb-xfixes | head -5
apt-cache policy plasma-workspace-wayland libxcb-xfixes-dev 2>&1
' 2>&1