#!/system/bin/sh
echo "=== sync test $(date) ==="
ps -ef 2>/dev/null | grep -E 'sync|jbd2/loop63' | grep -v grep
echo "starting sync..."
T1=$(date +%s)
/data/local/Droidspaces/bin/busybox sync
T2=$(date +%s)
echo "sync took $((T2-T1))s"
echo "=== if img mounted sync ==="
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
MNT=/data/local/tmp/sync-test-mnt
mkdir -p "$MNT"
losetup /dev/block/loop53 "$IMG" 2>/dev/null
mount -t ext4 -o rw "$MNT" 2>/dev/null && {
  T1=$(date +%s)
  /data/local/Droidspaces/bin/busybox sync
  T2=$(date +%s)
  echo "sync with img mounted took $((T2-T1))s"
  umount "$MNT"
}
losetup -d /dev/block/loop53 2>/dev/null
rmdir "$MNT" 2>/dev/null