#!/system/bin/sh
MP=/data/local/Droidspaces/Containers/sb2/rootfs
IMG=/data/local/Droidspaces/Containers/sb2/rootfs.img
echo "=== $(date) unmount hang research ==="
echo "--- mount state ---"
mount | grep -E 'sb2|loop63' || echo "(not in mount table)"
mountpoint "$MP" 2>&1
losetup -a 2>/dev/null | grep -E 'sb2|loop63' || echo "(no loop)"
echo "--- processes ---"
ps -ef 2>/dev/null | grep -E 'sync|umount|28194|26830|xzcat| tar ' | grep -v grep || echo none
echo "--- sh 28194 ---"
tr '\0' ' ' < /proc/28194/cmdline 2>/dev/null; echo
grep -E 'State|Wchan' /proc/28194/status 2>/dev/null
echo "--- timed sync (5s cap via timeout if exists) ---"
T1=$(date +%s)
if command -v timeout >/dev/null 2>&1; then
  timeout 5 /data/local/Droidspaces/bin/busybox sync; echo sync_timeout_exit=$?
else
  /data/local/Droidspaces/bin/busybox sync &
  SP=$!
  sleep 5
  if kill -0 $SP 2>/dev/null; then echo "sync still running after 5s (pid $SP)"; kill $SP 2>/dev/null; else wait $SP; echo sync_done; fi
fi
T2=$(date +%s)
echo "sync probe took $((T2-T1))s"
echo "--- timed umount -l ---"
T1=$(date +%s)
/data/local/Droidspaces/bin/busybox umount -l "$MP" 2>&1; EC=$?
T2=$(date +%s)
echo "umount -l took $((T2-T1))s exit=$EC"
mountpoint "$MP" 2>&1
echo "--- fuser/mountinfo ---"
grep sb2 /proc/20697/mountinfo 2>/dev/null | head -3
ls -l /proc/20697/fd 2>/dev/null | head -8
echo "=== done ==="