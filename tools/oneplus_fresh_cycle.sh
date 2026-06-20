#!/system/bin/sh
# OnePlus PKR110: fresh sparse install (official rootfs) + smoke/stress -> cleanup.
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
BB=/data/local/Droidspaces/bin/busybox
SCRIPT=/data/local/tmp/mount_loop_scan.sh
ROOTFS_XZ=/data/local/tmp/debian13-minimal-rootfs.tar.xz
ROOTFS_DL="/sdcard/Download/Debian-GNU-Linux-13-Trixie-Minimal-Droidspaces-developers-aarch64-20260615-385f0403.tar.xz"
ROOTFS_URL="https://github.com/Droidspaces/Droidspaces-rootfs-builder/releases/download/v20260615-175931/Debian-13-Minimal-Droidspaces-rootfs-aarch64-20260615-v20260615-175931.tar.xz"
NAME=sb-e2e
BASE=/data/local/Droidspaces/Containers/$NAME
IMG="$BASE/rootfs.img"
MP="$BASE/rootfs"
LOG=/data/local/tmp/oneplus_fresh_cycle_$(date +%Y%m%d_%H%M%S).log
FAIL=0

log() { echo "$@" | tee -a "$LOG"; }
pass() { log "[PASS] $1"; }
fail() { log "[FAIL] $1"; FAIL=1; }

cleanup_test() {
  "$DS" --name="$NAME" stop 2>/dev/null || true
  umount -l "/mnt/Droidspaces/$NAME" 2>/dev/null || true
  if [ -f "$IMG" ]; then
    losetup -a 2>/dev/null | grep -F "$IMG" | sed -n 's/:.*//p' | while read -r d; do
      losetup -d "$d" 2>/dev/null || true
    done
  fi
  rm -rf "$BASE"
}

cleanup_all() {
  cleanup_test
  rm -f "$ROOTFS_XZ"  # only remove tmp copy; keep user Downloads
  sh /data/local/tmp/delete_containers.sh sb sb-e2e 2>/dev/null || true
  sh /data/local/tmp/detach_stale_loops.sh 2>/dev/null || true
}

: >"$LOG"
log "========== OnePlus fresh cycle $(date) =========="
log "CLI=$(wc -c <"$DS") $(sha256sum "$DS" | awk '{print $1}')"
log "APK=$(pm path com.droidspaces.app 2>/dev/null | head -1)"

log "--- 1) ensure sb removed ---"
if [ -d /data/local/Droidspaces/Containers/sb ]; then
  sh /data/local/tmp/delete_containers.sh sb
fi
if [ -d /data/local/Droidspaces/Containers/sb ]; then
  fail "sb still exists"
else
  pass "no sb container"
fi

log "--- 2) locate Debian 13 Minimal rootfs (~101MB) ---"
ROOTFS_USE=""
for f in "$ROOTFS_DL" \
  /sdcard/Download/Debian-GNU-Linux-13-Trixie-Minimal*.tar.xz \
  /sdcard/Download/Debian-GNU-Linux-13-Trixie-Minimal*.tar-*.xz \
  "$ROOTFS_XZ"; do
  [ -f "$f" ] || continue
  sz=$(wc -c <"$f")
  if [ "$sz" -gt 90000000 ]; then
    ROOTFS_USE="$f"
    break
  fi
done
if [ -n "$ROOTFS_USE" ]; then
  pass "using rootfs $ROOTFS_USE ($(wc -c <"$ROOTFS_USE") bytes)"
else
  log "[*] no local rootfs; trying curl..."
  rm -f "$ROOTFS_XZ"
  if curl -4 -fL --retry 3 -o "$ROOTFS_XZ" "$ROOTFS_URL"; then
    ROOTFS_USE="$ROOTFS_XZ"
    pass "downloaded $(wc -c <"$ROOTFS_USE") bytes"
  else
    fail "rootfs missing"
    exit 1
  fi
fi

log "--- 3) mount_loop_scan smoke ---"
if sh /data/local/tmp/oneplus_apk_mount_smoke.sh 2>&1 | tee -a "$LOG" | grep -q 'ONEPLUS_MOUNT_SMOKE'; then
  pass "mount smoke"
else
  fail "mount smoke"
fi

log "--- 4) fresh sparse install (4G, App path + xz extract) ---"
cleanup_test
mkdir -p "$BASE" "$MP"
truncate -s 4G "$IMG"
mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0 -L droidspaces-rootfs "$IMG" >/dev/null 2>&1
tune2fs -m 0 "$IMG" 2>/dev/null || true
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true
if BUSYBOX_PATH="$BB" sh "$SCRIPT" "$IMG" "$MP" "rw,nodelalloc,noatime,nodiratime,init_itable=0"; then
  pass "install mount 4G"
else
  fail "install mount 4G"
  cleanup_all
  exit 1
fi
log "[*] extracting rootfs.xz (may take 2-5 min)..."
if (cd "$MP" && "$BB" xzcat "$ROOTFS_USE" | "$BB" tar -xpf -); then
  pass "xz tarball extract"
else
  fail "xz tarball extract"
  cleanup_all
  exit 1
fi
if [ -f "$MP/sbin/init" ] || [ -L "$MP/sbin/init" ]; then
  pass "rootfs has sbin/init"
else
  fail "missing sbin/init"
fi
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
pass "container.config before umount"
"$BB" umount -l "$MP" 2>/dev/null || umount -l "$MP" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | sed -n 's/:.*//p' | while read -r d; do
  losetup -d "$d" 2>/dev/null || true
done
rmdir "$MP" 2>/dev/null || true
pass "umount after config"

log "--- 5) start + network ---"
"$DS" --name="$NAME" --rootfs-img="$IMG" --hostname="$NAME" --net=nat --nat-ip=172.28.1.4 start 2>&1 | tail -6 | tee -a "$LOG"
sleep 10
if "$DS" show 2>/dev/null | grep -qF "$NAME"; then
  pass "$NAME RUNNING"
else
  fail "$NAME not running"
fi
if "$DS" --name="$NAME" run ping -c 2 -W 8 1.1.1.1 2>&1 | grep -q "bytes from"; then
  pass "ping"
else
  fail "ping"
fi
if "$DS" --name="$NAME" run sh -c 'curl -4 -sS -m 25 -o /dev/null -w "%{http_code}" https://deb.debian.org' 2>&1 | grep -qE '^200$'; then
  pass "curl"
else
  fail "curl"
fi

log "--- 6) 3x stop/start ---"
i=1
while [ "$i" -le 3 ]; do
  "$DS" --name="$NAME" stop 2>&1 | tail -1
  sleep 2
  "$DS" --name="$NAME" start 2>&1 | tail -1
  sleep 6
  if "$DS" show 2>/dev/null | grep -qF "$NAME"; then
    log "  round $i: OK"
  else
    fail "stop/start round $i"
    break
  fi
  i=$((i + 1))
done
[ "$FAIL" -eq 0 ] && pass "3x stop/start"

log "--- 7) loop stress 10 rounds ---"
if sh /data/local/tmp/loop_stress_named.sh "$NAME" 10 2>&1 | tee -a "$LOG" | grep -q 'ok=10 fail=0'; then
  pass "loop stress 10/10"
else
  fail "loop stress"
fi

log "--- 8) cleanup + free space ---"
"$DS" --name="$NAME" stop 2>/dev/null || true
cleanup_all
if [ -d "$BASE" ]; then
  fail "cleanup incomplete"
else
  pass "all test artifacts removed"
fi

log "containers: $(ls /data/local/Droidspaces/Containers/ 2>/dev/null | tr '\n' ' ' || echo none)"
log "free: $(df -h /data 2>/dev/null | tail -1)"
log "bound loops: $(losetup -a 2>/dev/null | wc -l)"
log "LOG=$LOG"
log "========== RESULT: $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) =========="
exit "$FAIL"