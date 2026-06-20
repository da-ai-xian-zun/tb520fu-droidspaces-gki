#!/system/bin/sh
# Diagnose why App loop-scan mount fails while adb su works.
set -u

IMG="${1:-/data/local/Droidspaces/Containers/mount-debug/rootfs.img}"
MNT="${2:-/data/local/Droidspaces/Containers/mount-debug/rootfs}"
OPTS="rw,nodelalloc,noatime,nodiratime,init_itable=0"
BB=/data/local/Droidspaces/bin/busybox
LOG=/data/local/tmp/diag_app_sparse_mount.log

: >"$LOG"
exec >>"$LOG" 2>&1

echo "========== diag $(date) =========="
echo "img=$IMG mnt=$MNT"
id
cat /proc/self/attr/current 2>/dev/null || true
echo "max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null)"
echo "bound=$(losetup -a 2>/dev/null | wc -l)"

rm -rf "$(dirname "$IMG")"
mkdir -p "$(dirname "$IMG")" "$MNT"
truncate -s 4G "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
e2fsck -fy "$IMG" >/dev/null 2>&1 || true
sync
sleep 2

# Exact SparseImageInstaller.buildLoopScanMountCmd (one line)
MOUNT_ONELINER='max_loop=64 if [ -r /sys/module/loop/parameters/max_loop ]; then max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo 64); fi start=48 [ "$start" -ge "$max_loop" ] && start=$((max_loop - 1)) i=$((max_loop - 1)) mounted=0 while [ "$i" -ge "$start" ]; do loop_dev="/dev/block/loop$i" if losetup "$loop_dev" 2>/dev/null; then i=$((i - 1)); continue; fi if losetup "$loop_dev" '"$IMG"' 2>/dev/null; then if mount -t ext4 -o '"$OPTS"' "$loop_dev" '"$MNT"' 2>/dev/null; then mounted=1; break; fi umount '"$MNT"' 2>/dev/null || true losetup -d "$loop_dev" 2>/dev/null || true fi i=$((i - 1)); done if [ "$mounted" != 1 ]; then '"$BB"' mount -t ext4 -o loop,'"$OPTS"' '"$IMG"' '"$MNT"' 2>/dev/null || mount -t ext4 -o loop,'"$OPTS"' '"$IMG"' '"$MNT"' 2>/dev/null || exit 1; fi'

echo "--- test A: bare oneliner (like Shell.cmd single string) ---"
eval "$MOUNT_ONELINER"
echo "A exit=$? mounted=$(mount | grep -c "$MNT" || true)"
umount "$MNT" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r d; do losetup -d "$d" 2>/dev/null; done

echo "--- test B: sh -c oneliner ---"
sh -c "$MOUNT_ONELINER"
echo "B exit=$? mounted=$(mount | grep -c "$MNT" || true)"
umount "$MNT" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r d; do losetup -d "$d" 2>/dev/null; done

echo "--- test C: structured script (known good) ---"
sh /data/local/tmp/test_apk_loop_scan_mount.sh "$IMG" "$MNT"

echo "LOG=$LOG"
cat "$LOG"