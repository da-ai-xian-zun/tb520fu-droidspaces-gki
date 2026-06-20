#!/system/bin/sh
STAGING=/data/local/Droidspaces/Containers/debian13/rootfs/var/anland-install
tar -tzf "$STAGING/mesa-anland-debian-trixie.tar.gz" | head -5
tar -tzf "$STAGING/mesa-anland-debian-trixie.tar.gz" | grep -E '\.deb$' | head -10