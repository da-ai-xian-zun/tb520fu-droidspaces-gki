#!/system/bin/sh
echo "=== sb2 state $(date) ==="
ls -la /data/local/Droidspaces/Containers/sb2/ 2>&1
ls -la /data/local/Droidspaces/Containers/sb2/container.config 2>&1
losetup -a 2>/dev/null | grep sb2
echo "--- sh wchan/stack ---"
for p in 28194 26830; do
  echo "pid $p: $(grep State /proc/$p/status 2>/dev/null) wchan=$(cat /proc/$p/wchan 2>/dev/null)"
done
echo "--- all app children ---"
ps -ef 2>/dev/null | awk '$3==26830 || $2==26830'
echo "--- img ok? ---"
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
wc -c "$IMG" 2>/dev/null
losetup /dev/block/loop54 "$IMG" 2>/dev/null && mount -t ext4 -o ro /dev/block/loop54 /data/local/tmp/v54 2>/dev/null
mkdir -p /data/local/tmp/v54
mount -t ext4 -o ro /dev/block/loop54 /data/local/tmp/v54 2>/dev/null && cat /data/local/tmp/v54/etc/os-release 2>/dev/null | head -2
umount /data/local/tmp/v54 2>/dev/null; losetup -d /dev/block/loop54 2>/dev/null