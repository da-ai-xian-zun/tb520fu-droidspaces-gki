#!/system/bin/sh
# Recover debian-cli sparse start when LOOP_SET_FD: Resource busy
set -u

DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian-cli
IMG=/data/local/Droidspaces/Containers/debian-cli/rootfs.img
MNT=/mnt/Droidspaces/debian-cli

echo "========== BEFORE =========="
getenforce 2>/dev/null || true
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
losetup -a 2>/dev/null | grep -F "$IMG" || echo "(img not on loop)"
mount 2>/dev/null | grep -E "Droidspaces/debian-cli|$IMG" || echo "(no debian-cli mount)"

echo "========== STOP + CLEANUP =========="
"$DS" --name="$NAME" stop 2>/dev/null || true
sleep 2
umount "$MNT" 2>/dev/null || true
umount /data/local/Droidspaces/Containers/debian-cli/rootfs 2>/dev/null || true

for i in $(seq 0 63); do
  if losetup -a 2>/dev/null | grep "loop$i" | grep -qF "$IMG"; then
    echo "detach loop$i"
    umount /dev/block/loop$i 2>/dev/null || true
    losetup -d /dev/block/loop$i 2>/dev/null || true
  fi
done
sync
sleep 1

echo -n "losetup after cleanup: "; losetup -a 2>/dev/null | wc -l

echo "========== START (CLI) =========="
"$DS" --config=/data/local/Droidspaces/Containers/debian-cli/container.config start 2>&1
sleep 5
if "$DS" show 2>/dev/null | grep -q "$NAME"; then
  echo "RESULT: SUCCESS"
  "$DS" show
else
  echo "RESULT: FAILED — try: adb reboot, then run this script again or start from App"
  exit 1
fi