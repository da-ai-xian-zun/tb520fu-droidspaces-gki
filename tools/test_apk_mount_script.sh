#!/system/bin/sh
set -eu
SCRIPT=/data/local/tmp/mount_loop_scan_apk.sh
BB=/data/local/Droidspaces/bin/busybox
IMG=/data/local/tmp/mount_apk_test.img
MNT=/data/local/tmp/mount_apk_test_mnt

echo "[*] test APK mount_loop_scan.sh $(date)"
sh -n "$SCRIPT"
echo "[OK] syntax"

rm -f "$IMG"
rm -rf "$MNT"
mkdir -p "$MNT"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

head -5 "$SCRIPT" | od -c | head -2

BUSYBOX_PATH="$BB" sh "$SCRIPT" "$IMG" "$MNT" "rw"
echo "[OK] mount_loop_scan exit=0"
mount | grep -F "$MNT"
umount "$MNT"
for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do losetup -d "$d" 2>/dev/null; done
rm -f "$IMG"
rmdir "$MNT"
echo "[OK] APK_MOUNT_TEST_PASS"