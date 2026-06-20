#!/system/bin/sh
echo "=== procs app tree ==="
ps -ef 2>/dev/null | grep -E '26830|28194|xzcat| tar |mount|loop63|sb2' | grep -v grep
echo "=== loop63 ==="
losetup /dev/block/loop63 2>/dev/null
mount 2>/dev/null | grep loop63 || echo "loop63 not mounted"
echo "=== sb2 files ==="
find /data/local/Droidspaces/Containers/sb2 -maxdepth 2 -ls 2>/dev/null
echo "=== temp mount grep ==="
grep -r sb2 /proc/mounts /proc/20697/mountinfo 2>/dev/null | head -10
echo "=== apk version hint ==="
ls -l /data/local/Droidspaces/bin/droidspaces /data/local/Droidspaces/bin/busybox 2>/dev/null
wc -c /data/local/Droidspaces/bin/droidspaces 2>/dev/null
echo "=== logcat ==="
logcat -d -t 800 2>/dev/null | grep -iE 'SPARSE|ContainerLogger|Install|sb2|mount_loop|loop-scan|busybox' | tail -80
echo "=== done ==="