#!/system/bin/sh
# Live sparse install investigation (TB520FU / loop-heavy)
set -u
echo "========== sparse install live $(date) =========="
echo "--- containers ---"
ls -la /data/local/Droidspaces/Containers/ 2>/dev/null || echo "(no Containers dir)"
for d in /data/local/Droidspaces/Containers/*/; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  echo "== $n =="
  ls -lh "$d"rootfs.img 2>/dev/null || ls -lh "$d"/*.img 2>/dev/null || echo "(no img)"
  du -sh "$d"rootfs.img 2>/dev/null || true
  wc -c "$d"rootfs.img 2>/dev/null || true
done
echo "--- install procs ---"
ps -ef 2>/dev/null | grep -E 'xzcat| tar |mount_loop|e2fsck|mkfs|truncate|losetup|SparseImage|droidspaces|com.droidspaces' | grep -v grep || echo "(none)"
echo "--- app cache scripts ---"
ls -la /data/user/0/com.droidspaces.app/cache/*.sh 2>/dev/null || ls -la /data/data/com.droidspaces.app/cache/*.sh 2>/dev/null || echo "(no cache scripts)"
echo "--- mount_loop_scan in cache ---"
for f in /data/user/0/com.droidspaces.app/cache/mount_loop_scan.sh /data/data/com.droidspaces.app/cache/mount_loop_scan.sh; do
  if [ -f "$f" ]; then
    echo "FILE $f"
    head -25 "$f"
    echo "..."
    tail -8 "$f"
  fi
done
echo "--- loop / mounts ---"
losetup -a 2>/dev/null | grep -E 'rootfs|Containers|Droidspaces' || echo "(no container loops)"
grep -E 'Containers|Droidspaces' /proc/mounts 2>/dev/null || echo "(no container mounts)"
awk 'NR>1 {if ($2+0>m) m=$2+0} END {print "max_used_minor=" m+0}' /proc/loops 2>/dev/null
cat /sys/module/loop/parameters/max_loop 2>/dev/null | awk '{print "sysfs_max_loop="$1}'
echo "--- logcat SPARSE (last 40) ---"
logcat -d -t 200 2>/dev/null | grep -iE '\[SPARSE\]|\[POST-FIX\]|SparseImage|mount_loop|loop-scan|busybox loop' | tail -40
echo "========== done =========="