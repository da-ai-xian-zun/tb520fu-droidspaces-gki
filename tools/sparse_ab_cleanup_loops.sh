#!/system/bin/sh
MP=/data/local/tmp/sparse-ab-fill-mnt
umount "$MP" 2>/dev/null || true
for i in $(seq 48 63); do
  losetup -d /dev/block/loop$i 2>/dev/null || true
done
echo "loops 48-63 cleared"
losetup -a 2>/dev/null | grep -E 'loop4[89]|loop5' || echo "(no test loops bound)"