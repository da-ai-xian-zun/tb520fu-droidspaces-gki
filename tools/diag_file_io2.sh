#!/bin/bash
set -u

echo "========== BALOO / THUMBNAILS =========="
dpkg -l 2>/dev/null | grep -E 'baloo|dolphin|thumbnail' || true
ls -la /root/.config/baloofilerc /root/.config/dolphinrc /root/.config/kservicerc5 2>/dev/null || true
cat /root/.config/baloofilerc 2>/dev/null || echo "(no baloofilerc)"
echo
pgrep -a baloo || echo "no baloo process"
pgrep -a dolphin || echo "no dolphin process"
du -sh /root/.cache/thumbnails /root/.local/share/baloo /root/.local/share/dolphin 2>/dev/null || true
echo

echo "========== FILE COUNTS =========="
echo -n "/usr/share files: "; find /usr/share -type f 2>/dev/null | wc -l
echo -n "/usr files: "; find /usr -type f 2>/dev/null | wc -l
echo -n "/root files: "; find /root -type f 2>/dev/null | wc -l
echo

echo "========== TIMING (no time cmd) =========="
t0=$(date +%s%N)
ls -1 /usr/share >/dev/null 2>&1
t1=$(date +%s%N)
echo "ls /usr/share: $(( (t1-t0)/1000000 )) ms"
t0=$(date +%s%N)
find /usr/share/wallpapers -type f 2>/dev/null | wc -l >/dev/null
t1=$(date +%s%N)
echo "find wallpapers: $(( (t1-t0)/1000000 )) ms"
t0=$(date +%s%N)
for i in $(seq 1 500); do stat /etc/passwd >/dev/null 2>&1; done
t1=$(date +%s%N)
echo "stat x500: $(( (t1-t0)/1000000 )) ms"
t0=$(date +%s%N)
find / -xdev -type f 2>/dev/null | wc -l >/dev/null
t1=$(date +%s%N)
echo "find all files on /: $(( (t1-t0)/1000000 )) ms"
echo

echo "========== MOUNT FULL =========="
cat /proc/self/mountinfo | head -30
echo "..."
cat /proc/self/mountinfo | wc -l
echo

echo "========== HOST ROOTFS PATH =========="
ls -la /data/local/Droidspaces/Containers/debian13/rootfs 2>/dev/null | head -5 || echo "path not visible inside container"
echo

echo "========== PACKAGEKIT =========="
systemctl is-active packagekit 2>/dev/null || true
pgrep -a packagekit || true