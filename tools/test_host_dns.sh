#!/system/bin/sh
echo "=== host ping github (shows resolved IP) ==="
ping -c1 -W3 github.com 2>&1
echo "=== host wget resolve ==="
busybox wget -q -O /dev/null -S https://github.com 2>&1 | grep -i '^  Connecting\|^  Location\|Resolving' | head -3