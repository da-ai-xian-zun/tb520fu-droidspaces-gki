#!/system/bin/sh
set -eu
SCRIPT=/data/local/tmp/mount_loop_scan.sh
IMG=/data/local/tmp/mount-script-test.img
MNT=/data/local/tmp/mount-script-test-mnt
rm -f "$IMG"
rm -rf "$MNT"
mkdir -p "$MNT"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
sh "$SCRIPT" "$IMG" "$MNT"
mount | grep mount-script-test-mnt
umount "$MNT"
losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | while read -r d; do losetup -d "$d" 2>/dev/null; done
rm -f "$IMG"
rmdir "$MNT"
echo SCRIPT_OK