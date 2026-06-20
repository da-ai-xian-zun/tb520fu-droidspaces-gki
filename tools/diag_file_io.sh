#!/bin/bash
set -u

echo "========== MOUNTS =========="
mount | grep -E 'rootfs|droidspaces|/data|overlay|bind' || mount | head -20
echo
df -hT / /root /home /tmp /usr 2>/dev/null || df -hT /
echo

echo "========== CONTAINER CONFIG =========="
cat /run/droidspaces/container.config 2>/dev/null || echo "(no container.config)"
echo

echo "========== FILE OP BENCHMARK =========="
for p in /root /usr/share/wallpapers /usr/share/pixmaps /; do
  [ -d "$p" ] || continue
  echo -n "readdir $p: "
  /usr/bin/time -f '%e sec' ls -1 "$p" >/dev/null 2>&1 || time ls -1 "$p" >/dev/null 2>&1
done
echo -n "stat 1000x /etc/passwd: "
/usr/bin/time -f '%e sec' sh -c 'for i in $(seq 1 1000); do stat /etc/passwd >/dev/null; done' 2>&1
echo -n "find /root -maxdepth 2: "
/usr/bin/time -f '%e sec' find /root -maxdepth 2 >/dev/null 2>&1
echo -n "find /usr/share -maxdepth 2 -type f | head: "
/usr/bin/time -f '%e sec' sh -c 'find /usr/share -maxdepth 2 -type f 2>/dev/null | head -100 >/dev/null' 2>&1
echo

echo "========== KDE / INDEX SERVICES =========="
ps aux 2>/dev/null | grep -E 'baloo|dolphin|kio|thumb|index|plasma|kded' | grep -v grep || ps -ef | grep -E 'baloo|dolphin|kio|thumb' | grep -v grep
echo
for svc in baloo baloo_file; do
  if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.baloo /BalooManager org.kde.baloo.Manager.status 2>/dev/null && echo "baloo status ok" || true
  fi
done
echo "baloo config:"
grep -r . /root/.config/baloofilerc 2>/dev>/dev/null | head -20 || echo "(no baloofilerc)"
echo

echo "========== INOTIFY =========="
cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || true
cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || true
echo

echo "========== HEAVY DIRS =========="
du -sh /root /root/.local /root/.cache /var/cache /usr/share 2>/dev/null | head -10
echo

echo "========== RECENT HIGH IO PROCS =========="
ps -eo pid,pcpu,pmem,comm --sort=-pcpu 2>/dev/null | head -15