#!/system/bin/sh
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
MNT=/data/local/tmp/sb2-pf-mnt
mkdir -p "$MNT"
losetup -d /dev/block/loop55 2>/dev/null
losetup /dev/block/loop55 "$IMG" 2>/dev/null
mount -t ext4 -o ro /dev/block/loop55 "$MNT" 2>/dev/null || exit 1
echo "droidspaces marker: $(ls -la $MNT/etc/droidspaces 2>/dev/null || echo missing)"
echo "machine-id: $(wc -c $MNT/etc/machine-id 2>/dev/null)"
echo "usr du: $(du -sh $MNT/usr 2>/dev/null)"
echo "total du: $(du -sh $MNT 2>/dev/null)"
umount "$MNT"; losetup -d /dev/block/loop55; rmdir "$MNT"
echo "sb droidspaces marker:"
IMG2=/data/local/Droidspaces/Containers/sb/rootfs.img
losetup /dev/block/loop56 "$IMG2" 2>/dev/null
mount -t ext4 -o ro /dev/block/loop56 /data/local/tmp/sb-pf-mnt 2>/dev/null
mkdir -p /data/local/tmp/sb-pf-mnt
ls -la /data/local/tmp/sb-pf-mnt/etc/droidspaces 2>/dev/null
umount /data/local/tmp/sb-pf-mnt 2>/dev/null; losetup -d /dev/block/loop56 2>/dev/null