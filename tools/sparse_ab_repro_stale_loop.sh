#!/system/bin/sh
# Try to reproduce LOOP_SET_FD / mount -o loop failure via stale loop (no reboot)
set -u
IMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
MP=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs
DS=/data/local/Droidspaces/bin/droidspaces

echo "=== baseline smoke ==="
sh /data/local/tmp/sparse_ab_module_isolate.sh smoke 2>&1 | grep RESULT

echo "=== leak loop48 (manual attach, no container) ==="
mkdir -p "$MP"
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
losetup -d /dev/block/loop48 2>/dev/null || true
losetup /dev/block/loop48 "$IMG" 2>&1 || true
losetup -a | grep loop48 || true

echo "=== smoke after leak (no umount) ==="
sh /data/local/tmp/sparse_ab_module_isolate.sh smoke 2>&1 | grep -E 'RESULT|LOOP_SET|losetup|Failed'

echo "=== cleanup ==="
umount "$MP" 2>/dev/null || true
losetup -d /dev/block/loop48 2>/dev/null || true
"$DS" --name=modtest-sparse stop 2>/dev/null || true

echo "=== smoke after cleanup ==="
sh /data/local/tmp/sparse_ab_module_isolate.sh smoke 2>&1 | grep RESULT