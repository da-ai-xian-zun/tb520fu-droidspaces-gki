#!/system/bin/sh
set -eu
SCRIPT=/data/local/tmp/mount_loop_scan_apk.sh
BB=/data/local/Droidspaces/bin/busybox
IMG=/data/local/tmp/op_mount_test.img
MNT=/data/local/tmp/op_mount_test_mnt

echo "[*] OnePlus mount smoke $(date)"
echo "[*] kernel=$(uname -r)"
echo "[*] max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo ?)"
echo "[*] bound=$(losetup -a 2>/dev/null | wc -l)"
echo "[*] cli_bytes=$(wc -c </data/local/Droidspaces/bin/droidspaces)"

sh -n "$SCRIPT"
echo "[OK] script syntax LF"

rm -f "$IMG"; rm -rf "$MNT"; mkdir -p "$MNT"
truncate -s 512M "$IMG"
mkfs.ext4 -F "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

echo "--- busybox loop ---"
"$BB" mount -t ext4 -o loop,rw "$IMG" "$MNT" 2>&1 || echo "busybox: fail"

echo "--- mount_loop_scan ---"
BUSYBOX_PATH="$BB" sh "$SCRIPT" "$IMG" "$MNT" "rw"
echo "[OK] mount_loop_scan"
mount | grep -F "$MNT"
umount "$MNT"
for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do losetup -d "$d" 2>/dev/null; done
rm -f "$IMG"; rmdir "$MNT"
echo "[PASS] ONEPLUS_MOUNT_SMOKE"