#!/system/bin/sh
# Time each finalize step for sb2 (read-only research)
set -u
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
MNT=/data/local/Droidspaces/Containers/sb2/rootfs
echo "=== state $(date) ==="
mount | grep -E 'sb2|loop63' || echo "(not mounted)"
losetup -a 2>/dev/null | grep -E 'sb2|loop63' || echo "(no loop)"
echo "mountpoint rootfs: $(mountpoint $MNT 2>&1)"
echo "rootfs dir:"
ls -la "$MNT" 2>/dev/null | head -8
echo "config: $(ls -la /data/local/Droidspaces/Containers/sb2/container.config 2>&1)"
echo "=== timed umount test ==="
T1=$(date +%s)
busybox umount -l "$MNT" 2>/dev/null || umount -l "$MNT" 2>/dev/null
T2=$(date +%s)
echo "umount took $((T2-T1))s exit=$?"
echo "=== timed awk detach (installer cmd) ==="
T1=$(date +%s)
awk -v p="$IMG" '$5==p {system("losetup -d /dev/block/loop"$2)}' /proc/loops 2>/dev/null
T2=$(date +%s)
echo "awk detach took $((T2-T1))s"
losetup -a 2>/dev/null | grep sb2 || echo "sb2 loop gone"
echo "=== timed rmdir ==="
T1=$(date +%s)
rmdir "$MNT" 2>/dev/null; EC=$?
T2=$(date +%s)
echo "rmdir took $((T2-T1))s exit=$EC"
ls -la /data/local/Droidspaces/Containers/sb2/ 2>/dev/null
echo "=== proc/loops format sample ==="
head -5 /proc/loops 2>/dev/null
grep sb2 /proc/loops 2>/dev/null || true
echo "=== app shell ==="
ps -ef 2>/dev/null | grep -E '26830|28194' | grep -v grep
cat /proc/28194/wchan 2>/dev/null; echo
echo "=== which awk ==="
which awk 2>/dev/null; toybox awk 'BEGIN{print "awk-ok"}' 2>/dev/null
echo "=== done ==="