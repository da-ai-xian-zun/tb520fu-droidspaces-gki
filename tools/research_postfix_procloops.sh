#!/system/bin/sh
echo "=== /proc/loops ==="
wc -l /proc/loops 2>/dev/null; cat /proc/loops 2>/dev/null | head -10
echo "=== losetup -l ==="
losetup -l 2>/dev/null | head -8
echo "=== losetup -a sb2 ==="
losetup -a 2>/dev/null | grep sb2
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
echo "=== detach via losetup -a grep ==="
for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do
  echo "try losetup -d $d"
  losetup -d "$d" 2>&1
done
losetup -a 2>/dev/null | grep sb2 || echo "sb2 detached"
echo "=== post_extract dry-run timing on mounted img ==="
MNT=/data/local/tmp/pf-test-mnt
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
mkdir -p "$MNT"
losetup /dev/block/loop54 "$IMG" 2>/dev/null
mount -t ext4 -o ro /dev/block/loop54 "$MNT" 2>/dev/null
if [ -f /data/local/Droidspaces/bin/busybox ]; then
  BB=/data/local/Droidspaces/bin/busybox
  PF=/data/user/0/com.droidspaces.app/cache/post_extract_fixes.sh
  if [ ! -f "$PF" ]; then PF=$(ls /data/user/0/com.droidspaces.app/cache/*.sh 2>/dev/null | head -1); fi
  if [ -f "$PF" ]; then
    T1=$(date +%s)
    BUSYBOX_PATH=$BB sh "$PF" "$MNT" 2>&1 | tail -5
    T2=$(date +%s)
    echo "post_extract on ro mount took $((T2-T1))s"
  else
    echo "no post_extract in cache"
  fi
fi
umount "$MNT" 2>/dev/null; losetup -d /dev/block/loop54 2>/dev/null; rmdir "$MNT" 2>/dev/null