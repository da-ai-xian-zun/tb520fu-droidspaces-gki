#!/system/bin/sh
# E2E: simulate App Sparse 新建 (loop-scan mount + container.config) on TB520FU.
# Leaves container apk-e2e-sparse visible in Droidspaces App.
set -eu

NAME=apk-e2e-sparse
BASE=/data/local/Droidspaces/Containers/$NAME
IMG="$BASE/rootfs.img"
MP=/data/local/tmp/apk-e2e-mnt
DS=/data/local/Droidspaces/bin/droidspaces
LOG=/data/local/tmp/apk_sparse_e2e_$(date +%Y%m%d_%H%M%S).log
SIZE_G=1
SRC=debian-cli

exec >"$LOG" 2>&1
echo "========== APK sparse E2E $NAME $(date) =========="
echo "droidspaces bytes: $(wc -c <"$DS")"

# cleanup prior run + orphan CLI test dir without config
if [ -d "$BASE" ]; then
  "$DS" --name="$NAME" stop 2>/dev/null || true
  sleep 2
  rm -rf "$BASE"
fi

mkdir -p "$BASE" "$MP"

echo "[1/6] Create ${SIZE_G}G sparse image"
truncate -s ${SIZE_G}G "$IMG"
mkfs.ext4 -F -L "$NAME" "$IMG" >/dev/null 2>&1
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
ls -lh "$IMG"

echo "[2/6] loop-scan mount (SparseImageInstaller path)"
max_loop=64
if [ -r /sys/module/loop/parameters/max_loop ]; then
  max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo 64)
fi
start=48
[ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))
i=$((max_loop - 1))
mounted=0
loop_used=""
while [ "$i" -ge "$start" ]; do
  loop_dev="/dev/block/loop$i"
  if losetup "$loop_dev" 2>/dev/null; then
    i=$((i - 1))
    continue
  fi
  if losetup "$loop_dev" "$IMG" 2>/dev/null; then
    if mount -t ext4 -o rw,nodelalloc,noatime,nodiratime,init_itable=0 "$loop_dev" "$MP" 2>/dev/null; then
      mounted=1
      loop_used=$i
      echo "    mounted on loop$i"
      break
    fi
    umount "$MP" 2>/dev/null || true
    losetup -d "$loop_dev" 2>/dev/null || true
  fi
  i=$((i - 1))
done
if [ "$mounted" != 1 ]; then
  echo "FAIL: loop-scan mount"
  exit 1
fi

echo "[3/6] Seed minimal rootfs from running $SRC"
if ! "$DS" show 2>/dev/null | grep -q "$SRC"; then
  echo "FAIL: source container $SRC not running"
  exit 1
fi
# Copy enough of Debian rootfs for droidspaces start (sbin/init + dynamic linker + core libs)
"$DS" --name="$SRC" run sh -c '
  set -e
  tar -cf - \
    bin bin.usr-is-merged \
    sbin sbin.usr-is-merged \
    lib lib64 etc/passwd etc/group etc/hostname etc/hosts etc/nsswitch.conf etc/resolv.conf \
    etc/apt etc/dpkg etc/debian_version usr/lib/aarch64-linux-gnu usr/lib64 \
    var/lib/dpkg var/cache/apt archives/partial \
    root tmp run proc sys dev 2>/dev/null || \
  tar -cf - bin sbin lib etc/passwd etc/group etc/hostname etc/hosts etc/resolv.conf usr/lib/aarch64-linux-gnu root tmp run
' | tar -xf - -C "$MP"
sync
echo "    rootfs seeded ($(du -sh "$MP" | awk "{print \$1}"))"

echo "[4/6] Unmount + detach loop"
umount "$MP"
losetup -d "/dev/block/loop$loop_used" 2>/dev/null || true
rmdir "$MP" 2>/dev/null || true

echo "[5/6] Write container.config (App-visible)"
cat >"$BASE/container.config" <<EOF
# Droidspaces Container Configuration
# APK sparse E2E test $(date +%Y-%m-%d)

name=$NAME
hostname=$NAME
rootfs_path=$IMG
net_mode=none
disable_ipv6=1
enable_android_storage=0
enable_hw_access=0
enable_gpu_mode=0
enable_termux_x11=0
enable_virgl=0
enable_pulseaudio=0
selinux_permissive=0
volatile_mode=0
run_at_boot=0
force_cgroupv1=0
block_nested_ns=0
use_sparse_image=1
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || date +%s)
EOF
chmod 644 "$BASE/container.config"
ls -la "$BASE"

echo "[6/6] droidspaces start + verify"
"$DS" --name="$NAME" --rootfs-img="$IMG" --hostname="$NAME" --net=none start
sleep 6
if "$DS" show 2>/dev/null | grep -q "$NAME"; then
  echo "RESULT: SUCCESS start"
  "$DS" --name="$NAME" run echo "RESULT: SUCCESS enter" 2>&1 || true
  "$DS" --name="$NAME" stop 2>/dev/null || true
  sleep +2
else
  echo "RESULT: FAIL start"
  "$DS" show 2>&1 || true
  exit 1
fi

echo "LOG=$LOG"
echo "========== DONE =========="