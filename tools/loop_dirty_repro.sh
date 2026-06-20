#!/system/bin/sh
# Aggressively dirty loop pool then stress start — no reboot
set -u

DS=/data/local/Droidspaces/bin/droidspaces
IMG=/data/local/Droidspaces/Containers/debian-cli/rootfs.img
TMP=/data/local/tmp/loop-dirty-test.img
MP=/data/local/tmp/loop-dirty-mnt

echo "========== PHASE 1: leak loops 48-55 =========="
truncate -s 64M "$TMP" 2>/dev/null
mkfs.ext4 -F "$TMP" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$TMP" 2>/dev/null || true
mkdir -p "$MP"

for i in 48 49 50 51 52 53 54 55; do
  losetup -d /dev/block/loop$i 2>/dev/null || true
  losetup /dev/block/loop$i "$TMP" 2>&1 || echo "  leak loop$i: fail"
done
echo -n "bound after leak: "; losetup -a 2>/dev/null | wc -l

echo "========== PHASE 2: toybox mount -o loop (APEX-margin path) =========="
mount -t ext4 -o loop,rw "$TMP" "$MP" 2>&1 || true
mount | grep loop-dirty-mnt && umount "$MP" 2>/dev/null || echo "toybox loop: failed"

echo "========== PHASE 3: CLI start debian-cli (should use LOOP_CTL_GET_FREE) =========="
"$DS" --name=debian-cli stop 2>/dev/null || true
sleep 2
out=$("$DS" --name=debian-cli start 2>&1) || true
sleep 5
if "$DS" show 2>/dev/null | grep -q debian-cli; then
  echo "RESULT after dirty leak: SUCCESS"
else
  echo "RESULT after dirty leak: FAILED"
  echo "$out" | tail -8
fi

echo "========== PHASE 4: cleanup leaks =========="
for i in 48 49 50 51 52 53 54 55; do
  umount /dev/block/loop$i 2>/dev/null || true
  losetup -d /dev/block/loop$i 2>/dev/null || true
done
"$DS" --name=debian-cli stop 2>/dev/null || true
sleep 2
out=$("$DS" --name=debian-cli start 2>&1) || true
sleep 5
if "$DS" show 2>/dev/null | grep -q debian-cli; then
  echo "RESULT after cleanup: SUCCESS"
else
  echo "RESULT after cleanup: FAILED"
  echo "$out" | tail -8
fi

rm -f "$TMP" 2>/dev/null
rmdir "$MP" 2>/dev/null || true