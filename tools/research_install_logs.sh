#!/system/bin/sh
echo "=== procs ==="
ps -ef 2>/dev/null | grep -E 'xzcat| tar |e2fsck|sync|post_extract' | grep -v grep || echo none
echo "=== sh 28194 ==="
tr '\0' ' ' < /proc/28194/cmdline 2>/dev/null; echo
grep State /proc/28194/status 2>/dev/null
echo "=== logcat ContainerLogger ==="
logcat -d -t 4000 2>/dev/null | grep ContainerLogger | tail -50
echo "=== cache tarballs ==="
ls -la /data/data/com.droidspaces.app/cache/container_sb* 2>/dev/null
ls -la /data/data/com.droidspaces.app/cache/*.config 2>/dev/null
echo "=== done ==="