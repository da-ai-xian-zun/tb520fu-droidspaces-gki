#!/system/bin/sh
DS=/data/local/Droidspaces/bin/droidspaces
ROOTFS=/data/local/Droidspaces/Containers/debian13/rootfs
cp /data/local/tmp/container_install_anland.sh "$ROOTFS/usr/local/bin/container_install_anland.sh"
chmod 755 "$ROOTFS/usr/local/bin/container_install_anland.sh"
nohup $DS --name=debian13 run bash /usr/local/bin/container_install_anland.sh > /data/local/tmp/anland-install-host.log 2>&1 &
sleep 4
tail -15 /data/local/tmp/anland-install-host.log