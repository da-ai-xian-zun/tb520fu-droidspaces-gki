#!/system/bin/sh
echo "========== install stuck diag $(date) =========="
echo "--- sb container ---"
ls -la /data/local/Droidspaces/Containers/sb/ 2>/dev/null
ls -la /data/local/Droidspaces/Containers/sb/rootfs/ 2>/dev/null | head -15
echo "img du1: $(du -sh /data/local/Droidspaces/Containers/sb/rootfs.img 2>/dev/null)"
sleep 8
echo "img du2: $(du -sh /data/local/Droidspaces/Containers/sb/rootfs.img 2>/dev/null)"
echo "--- mounts ---"
grep -E 'sb/rootfs|loop63|rootfs.img' /proc/mounts 2>/dev/null || echo "(no sb mount)"
losetup -a 2>/dev/null | grep sb || echo "(no sb loop)"
echo "--- app sh children ---"
ps -ef 2>/dev/null | awk '$3==26830 || $3==26879 || $2==26879 {print}'
echo "--- xz/tar/busybox under app ---"
ps -ef 2>/dev/null | grep -E 'xzcat| tar |mount_loop|e2fsck|mkfs' | grep -v grep
echo "--- cache tarball ---"
ls -lh /data/data/com.droidspaces.app/cache/container_sb* 2>/dev/null || ls -lh /data/user/0/com.droidspaces.app/cache/container_sb* 2>/dev/null
echo "========== done =========="