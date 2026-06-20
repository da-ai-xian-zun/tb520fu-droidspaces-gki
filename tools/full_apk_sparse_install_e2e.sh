#!/system/bin/sh
# Full App sparse install path E2E (TB520FU loopfix APK).
# Mirrors: SparseImageInstaller (mount_loop_scan) -> extract -> config -> unmount -> start -> net -> 3x stop/start
set -eu

NAME=sb-e2e
BASE=/data/local/Droidspaces/Containers/$NAME
IMG="$BASE/rootfs.img"
MP="$BASE/rootfs"
TAR=/data/local/tmp/${NAME}_rootfs.tar
DS=/data/local/Droidspaces/bin/droidspaces
BB=/data/local/Droidspaces/bin/busybox
SCRIPT=/data/local/tmp/mount_loop_scan.sh
LOG=/data/local/tmp/full_apk_sparse_install_e2e_$(date +%Y%m%d_%H%M%S).log
SIZE_G=4
SRC=debian-cli
FAIL=0

log() { echo "$@" | tee -a "$LOG"; }
pass() { log "[PASS] $1"; }
fail() { log "[FAIL] $1"; FAIL=1; }

detach_img() {
  [ -f "$IMG" ] || return 0
  losetup -a 2>/dev/null | grep -F "$IMG" | sed -n 's/:.*//p' | while read -r d; do
    losetup -d "$d" 2>/dev/null || true
  done
}

cleanup() {
  "$DS" --name="$NAME" stop 2>/dev/null || true
  umount -l "/mnt/Droidspaces/$NAME" 2>/dev/null || true
  umount -l "$MP" 2>/dev/null || true
  detach_img
  rm -rf "$BASE" "$TAR" 2>/dev/null || true
}

detach_stale() {
  for img in /data/local/Droidspaces/Containers/sb/rootfs.img \
             /data/local/Droidspaces/Containers/sb-e2e/rootfs.img; do
    losetup -a 2>/dev/null | grep -F "$img" | sed -n 's/:.*//p' | while read -r d; do
      losetup -d "$d" 2>/dev/null || true
    done
  done
}

: >"$LOG"
log "========== full APK sparse install E2E $(date) =========="
log "CLI=$(wc -c <"$DS") APK=$(pm path com.droidspaces.app 2>/dev/null | head -1)"

cleanup
detach_stale

log "--- A) mount_loop_scan.sh asset test (512M) ---"
if [ ! -f "$SCRIPT" ]; then
  fail "missing $SCRIPT"
else
  if sh -n "$SCRIPT" 2>/dev/null; then
    pass "mount_loop_scan.sh syntax"
  else
    fail "mount_loop_scan.sh syntax"
  fi
  if grep -q $'\r' "$SCRIPT" 2>/dev/null; then
    fail "mount_loop_scan.sh has CRLF"
  else
    pass "mount_loop_scan.sh LF-only"
  fi
  TIMG=/data/local/tmp/e2e_mountscript.img
  TMNT=/data/local/tmp/e2e_mountscript_mnt
  rm -f "$TIMG"; rm -rf "$TMNT"; mkdir -p "$TMNT"
  truncate -s 512M "$TIMG"
  mkfs.ext4 -F "$TIMG" >/dev/null 2>&1
  chcon u:object_r:vold_data_file:s0 "$TIMG" 2>/dev/null || true
  if BUSYBOX_PATH="$BB" sh "$SCRIPT" "$TIMG" "$TMNT" "rw,nodelalloc,noatime,nodiratime,init_itable=0"; then
    pass "mount_loop_scan.sh 512M mount"
    umount "$TMNT" 2>/dev/null || true
    detach_img
    losetup -a 2>/dev/null | grep -F "$TIMG" | sed -n 's/:.*//p' | while read -r d; do losetup -d "$d" 2>/dev/null; done
    rm -f "$TIMG"; rmdir "$TMNT" 2>/dev/null || true
  else
    fail "mount_loop_scan.sh 512M mount"
  fi
fi

log "--- B) build tarball from $SRC ---"
if ! "$DS" show 2>/dev/null | grep -qF "$SRC"; then
  log "[*] starting $SRC for tarball export"
  "$DS" --config=/data/local/Droidspaces/Containers/$SRC/container.config start 2>&1 | tail -5
  sleep 8
fi
if ! "$DS" show 2>/dev/null | grep -qF "$SRC"; then
  fail "source $SRC not running"
else
  log "[*] exporting tarball (may take 1-3 min)..."
  rm -f "$TAR"
  if "$DS" --name="$SRC" run tar -cpf - bin sbin lib etc usr var 2>/dev/null >"$TAR"; then
    :
  fi
  if [ -s "$TAR" ]; then
    pass "tarball ready $(wc -c <"$TAR") bytes"
  else
    fail "tarball empty"
  fi
fi

log "--- C) SparseImageInstaller-style install (${SIZE_G}G) ---"
mkdir -p "$BASE" "$MP"

log "[C1] truncate + mkfs"
truncate -s ${SIZE_G}G "$IMG"
mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0 -L "droidspaces-rootfs" "$IMG" >/dev/null 2>&1
tune2fs -m 0 "$IMG" 2>/dev/null || true
e2fsck -fy "$IMG" >/dev/null 2>&1 || true
sync
sleep 2
chcon u:object_r:vold_data_file:s0 "$IMG" 2>/dev/null || true

log "[C2] mount via mount_loop_scan.sh (App path)"
if BUSYBOX_PATH="$BB" sh "$SCRIPT" "$IMG" "$MP" "rw,nodelalloc,noatime,nodiratime,init_itable=0"; then
  pass "install mount ${SIZE_G}G"
else
  fail "install mount ${SIZE_G}G"
  cleanup
  exit 1
fi

log "[C3] extract tarball"
if [ -s "$TAR" ]; then
  if (cd "$MP" && "$BB" tar -xpf "$TAR" 2>&1); then
    pass "tarball extract"
  else
    fail "tarball extract"
  fi
else
  fail "skip extract (no tar)"
fi

log "[C4] write container.config BEFORE umount (new install order)"
cat >"$BASE/container.config" <<EOF
# Droidspaces Container Configuration
name=$NAME
hostname=$NAME
rootfs_path=$IMG
net_mode=nat
disable_ipv6=0
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
if [ -f "$BASE/container.config" ] && grep -q "use_sparse_image=1" "$BASE/container.config"; then
  pass "container.config written before umount"
else
  fail "container.config"
fi

log "[C5] unmountSparseImage-style cleanup"
"$BB" umount -l "$MP" 2>/dev/null || umount -l "$MP" 2>/dev/null || true
losetup -a 2>/dev/null | grep -F "$IMG" | sed -n 's/:.*//p' | while read -r d; do losetup -d "$d" 2>/dev/null; done
rmdir "$MP" 2>/dev/null || true
if mountpoint -q "$MP" 2>/dev/null || losetup -a 2>/dev/null | grep -qF "$IMG"; then
  fail "post-install umount/detach"
else
  pass "umount + loop detach after config"
fi

log "--- D) droidspaces check ---"
if "$DS" check 2>&1 | grep -q "All required features found"; then
  pass "droidspaces check"
else
  fail "droidspaces check"
fi

log "--- E) start $NAME + network ---"
"$DS" --name="$NAME" --rootfs-img="$IMG" --hostname="$NAME" --net=nat --nat-ip=172.28.1.4 start 2>&1 | tail -8
sleep 8
if "$DS" show 2>/dev/null | grep -qF "$NAME"; then
  pass "$NAME RUNNING"
else
  fail "$NAME not running"
fi

if "$DS" --name="$NAME" run ping -c 2 -W 5 1.1.1.1 2>&1 | grep -q "bytes from"; then
  pass "ping 1.1.1.1"
else
  fail "ping 1.1.1.1"
fi
if "$DS" --name="$NAME" run sh -c 'curl -4 -sS -m 20 -o /dev/null -w "%{http_code}" https://deb.debian.org' 2>&1 | grep -qE '^200$'; then
  pass "curl deb.debian.org"
else
  fail "curl deb.debian.org"
fi

log "--- F) 3x stop/start (loop dirty pool) ---"
i=1
while [ "$i" -le 3 ]; do
  "$DS" --name="$NAME" stop 2>&1 | tail -1
  sleep 2
  "$DS" --name="$NAME" start 2>&1 | tail -2
  sleep 6
  if "$DS" show 2>/dev/null | grep -qF "$NAME"; then
    log "  round $i: OK"
  else
    fail "stop/start round $i"
    break
  fi
  i=$((i + 1))
done
[ "$FAIL" -eq 0 ] && pass "$NAME 3x stop/start"

log "--- G) cleanup test container ---"
cleanup
if [ -d "$BASE" ]; then
  fail "cleanup left $BASE"
else
  pass "deleted $NAME"
fi
rm -f "$TAR"
log "free: $(df -h /data 2>/dev/null | tail -1)"
log "losetup bound=$(losetup -a 2>/dev/null | wc -l)"
log "LOG=$LOG"
log "========== RESULT: $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) =========="
exit "$FAIL"