#!/system/bin/sh
# Compare App-style mount vs CLI --rootfs-img on TB520FU (live)
set -u

DS=/data/local/Droidspaces/bin/droidspaces
BASE=/data/local/Droidspaces/Containers
TEST_IMG="$BASE/debian-cli-sparse-test/rootfs.img"
SB_IMG="$BASE/sb-cli-test/rootfs.img"
MP=/data/local/tmp/sparse-cli-test-mnt

echo "========== ENV =========="
getprop ro.product.model
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
cat /sys/module/loop/parameters/max_loop 2>/dev/null
df -h /data | tail -1
echo

echo "========== APP BUSYBOX mount -o loop (4G fresh img) =========="
mkdir -p "$BASE/sb-cli-test"
rm -f "$SB_IMG" 2>/dev/null
truncate -s 4G "$SB_IMG"
mkfs.ext4 -F "$SB_IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$SB_IMG" 2>/dev/null || true
mkdir -p "$MP"
BB=/data/local/Droidspaces/bin/busybox
echo "busybox: $BB"
if [ -x "$BB" ]; then
  echo "--- busybox mount minimal loop,rw (App-like) ---"
  "$BB" mount -t ext4 -o loop,rw "$SB_IMG" "$MP" 2>&1
  echo "exit=$?"
  if mount | grep -q sparse-cli-test-mnt; then
    echo "RESULT app_busybox_mount: SUCCESS"
    umount "$MP" 2>/dev/null || true
  else
    echo "RESULT app_busybox_mount: FAILED"
  fi
  echo "--- busybox mount with App extra opts ---"
  "$BB" mount -t ext4 -o loop,rw,nodelalloc,noatime,nodiratime,init_itable=0 "$SB_IMG" "$MP" 2>&1
  echo "exit=$?"
  mount | grep sparse-cli-test-mnt && umount "$MP" 2>/dev/null || true
else
  echo "no busybox at $BB"
fi
echo

echo "========== TOYBOX mount -o loop =========="
mount -t ext4 -o loop,rw "$SB_IMG" "$MP" 2>&1
echo "toybox exit=$?"
mount | grep sparse-cli-test-mnt && umount "$MP" 2>/dev/null || true
echo

echo "========== EXPLICIT losetup loop48+ =========="
FREE=""
for i in $(seq 48 63); do
  losetup /dev/block/loop$i 2>/dev/null && continue
  FREE=$i
  break
done
echo "free loop: ${FREE:-none}"
if [ -n "$FREE" ]; then
  losetup /dev/block/loop$FREE "$SB_IMG" 2>&1
  mount -t ext4 -o rw /dev/block/loop$FREE "$MP" 2>&1
  if mount | grep -q sparse-cli-test-mnt; then
    echo "RESULT explicit_losetup: SUCCESS"
    umount "$MP"; losetup -d /dev/block/loop$FREE 2>/dev/null || true
  else
    echo "RESULT explicit_losetup: FAILED"
    losetup -d /dev/block/loop$FREE 2>/dev/null || true
  fi
fi
echo

echo "========== CLI --rootfs-img (existing 1.9G test img) =========="
if [ -f "$TEST_IMG" ]; then
  "$DS" --name=cli-sb-test --rootfs-img="$TEST_IMG" --hostname=cli-sb-test --net=none start 2>&1
  sleep 5
  if "$DS" show 2>/dev/null | grep -q cli-sb-test; then
    echo "RESULT cli_rootfs_img_existing: SUCCESS"
    "$DS" --name=cli-sb-test stop 2>&1
  else
    echo "RESULT cli_rootfs_img_existing: FAILED"
    "$DS" show 2>&1
  fi
else
  echo "SKIP no $TEST_IMG"
fi
echo

echo "========== CLI --rootfs-img (fresh 4G sb-cli-test img) =========="
"$DS" --name=cli-sb-4g --rootfs-img="$SB_IMG" --hostname=cli-sb-4g --net=none start 2>&1
sleep 5
if "$DS" show 2>/dev/null | grep -q cli-sb-4g; then
  echo "RESULT cli_rootfs_img_4g: SUCCESS"
  "$DS" --name=cli-sb-4g stop 2>&1
else
  echo "RESULT cli_rootfs_img_4g: FAILED"
fi

rmdir "$MP" 2>/dev/null || true
echo "========== DONE =========="