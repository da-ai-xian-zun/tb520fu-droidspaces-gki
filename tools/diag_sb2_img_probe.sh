#!/system/bin/sh
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
MNT=/data/local/tmp/sb2-probe-mnt
echo "=== sb2 config ==="
cat /data/local/Droidspaces/Containers/sb2/container.config 2>/dev/null
echo "=== sb config ==="
cat /data/local/Droidspaces/Containers/sb/container.config 2>/dev/null
echo "=== probe mount sb2 img ==="
mkdir -p "$MNT"
# try loop-scan style mount without busybox loop
for i in 55 56 57 58 59 60 61 62 63; do
  losetup /dev/block/loop$i 2>/dev/null && continue
  losetup /dev/block/loop$i "$IMG" 2>/dev/null && { DEV=loop$i; break; }
done
if [ -z "${DEV:-}" ]; then
  DEV=loop63
  losetup -d /dev/block/loop63 2>/dev/null
  losetup /dev/block/loop63 "$IMG" 2>/dev/null || { echo "losetup fail"; exit 1; }
fi
echo "using $DEV"
mount -t ext4 -o ro "/dev/block/$DEV" "$MNT" 2>/dev/null || { echo "mount fail"; losetup -d "/dev/block/$DEV" 2>/dev/null; exit 1; }
echo "root listing:"
ls -la "$MNT" | head -20
echo "etc/os-release:"
cat "$MNT/etc/os-release" 2>/dev/null | head -5
echo "du top:"
du -sh "$MNT"/* 2>/dev/null | head -10
umount "$MNT" 2>/dev/null
losetup -d "/dev/block/$DEV" 2>/dev/null
rmdir "$MNT" 2>/dev/null
echo "=== sh 28194 cmdline ==="
tr '\0' ' ' < /proc/28194/cmdline 2>/dev/null; echo
echo "=== wchan 28194 ==="
cat /proc/28194/wchan 2>/dev/null; echo