#!/system/bin/sh
DEV=/dev/block/loop63
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
echo "=== loop63 status ==="
losetup -a 2>/dev/null | grep loop63
mount | grep loop63
fuser -v "$DEV" 2>&1 | head -5
echo "=== losetup -d attempts ==="
losetup -d "$DEV" 2>&1; echo exit=$?
losetup -D 2>&1 | head -3
losetup -a 2>/dev/null | grep loop63 || echo gone
echo "=== loop62 stale ==="
losetup -a 2>/dev/null | grep loop62
losetup -d /dev/block/loop62 2>&1; echo exit=$?
losetup -a 2>/dev/null | grep loop62 || echo loop62 gone