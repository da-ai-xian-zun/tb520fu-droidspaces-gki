#!/system/bin/sh
# OnePlus PKR110: agent-driven sparse install via stock mount chain (no mount_loop_scan).
set -u

DS=/data/local/Droidspaces/bin/droidspaces
BB=/data/local/Droidspaces/bin/busybox
NAME=sb-auto
BASE=/data/local/Droidspaces/Containers/$NAME
IMG="$BASE/rootfs.img"
MP="$BASE/rootfs"
OPTS=loop,rw,nodelalloc,noatime,nodiratime,init_itable=0
ROOTFS=/sdcard/Download/Debian-GNU-Linux-13-Trixie-Minimal-Droidspaces-developers-aarch64-20260615-385f0403.tar.xz
LOG=/data/local/tmp/oneplus_stock_agent_install.log

log() { echo "$@" | tee -a "$LOG"; }

: >"$LOG"
log "=== oneplus_stock_agent_install $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
log "cli_bytes=$(wc -c <"$DS")"
log "kernel=$(uname -r) max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null) bound=$(losetup -a 2>/dev/null | wc -l)"

"$DS" --name="$NAME" stop 2>/dev/null || true
umount -l "$MP" 2>/dev/null || true
rm -rf "$BASE"
mkdir -p "$BASE" "$MP"

log "--- create 4G sparse img ---"
truncate -s 4G "$IMG"
mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0 -L droidspaces-rootfs "$IMG" >/dev/null 2>&1
tune2fs -m 0 "$IMG" 2>/dev/null || true
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

log "--- stock mount chain (busybox || system) ---"
if "$BB" mount -t ext4 -o "$OPTS" "$IMG" "$MP" 2>>"$LOG"; then
  log "RESULT mount: busybox SUCCESS"
elif mount -t ext4 -o "$OPTS" "$IMG" "$MP" 2>>"$LOG"; then
  log "RESULT mount: system SUCCESS"
else
  log "RESULT mount: FAILED"
  exit 1
fi

log "--- extract rootfs ---"
if [ ! -f "$ROOTFS" ]; then
  log "ERROR: missing $ROOTFS"
  exit 1
fi
if (cd "$MP" && "$BB" xzcat "$ROOTFS" | "$BB" tar -xpf -); then
  log "RESULT extract: SUCCESS"
else
  log "RESULT extract: FAILED"
  exit 1
fi

log "--- write container.config ---"
cat >"$BASE/container.config" <<EOF
name=$NAME
hostname=$NAME
rootfs_path=$IMG
net_mode=nat
disable_ipv6=0
use_sparse_image=1
sparse_image_size_gb=4
EOF
chmod 644 "$BASE/container.config"

"$BB" umount -l "$MP" 2>/dev/null || umount -l "$MP" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | sed -n 's/:.*//p' | while read -r d; do
  losetup -d "$d" 2>/dev/null || true
done
rmdir "$MP" 2>/dev/null || true
log "RESULT umount: OK"

log "--- CLI start $NAME ---"
"$DS" --name="$NAME" --rootfs-img="$IMG" --hostname="$NAME" --net=nat --upstream=wlan0 --nat-ip=172.28.1.5 start 2>&1 | tee -a "$LOG"
sleep 8
if "$DS" show 2>/dev/null | grep -qF "$NAME"; then
  log "RESULT start: SUCCESS"
else
  log "RESULT start: FAILED"
  exit 1
fi

if "$DS" --name="$NAME" run ping -c 2 -W 8 1.1.1.1 2>&1 | grep -q "bytes from"; then
  log "RESULT ping: SUCCESS"
else
  log "RESULT ping: FAILED"
fi

log "=== end ==="