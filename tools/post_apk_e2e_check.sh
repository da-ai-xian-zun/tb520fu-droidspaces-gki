#!/system/bin/sh
# TB520FU post-魔改-APK E2E checklist (official NAT auto-uplink path)
set -u
DS=/data/local/Droidspaces/bin/droidspaces
LOG=/data/local/tmp/post_apk_e2e_$(date +%Y%m%d_%H%M%S).log
FAIL=0

log() { echo "$@" | tee -a "$LOG"; }
pass() { log "[PASS] $1"; }
fail() { log "[FAIL] $1"; FAIL=1; }

: >"$LOG"
log "========== post APK E2E $(date) =========="
log "CLI bytes: $(wc -c <"$DS")"
log "APK: $(pm path com.droidspaces.app 2>/dev/null | head -1)"

log "--- 1) droidspaces check ---"
if "$DS" check 2>&1 | grep -q "All required features found"; then
  pass "droidspaces check"
else
  fail "droidspaces check"
fi

log "--- 2) containers ---"
ls -la /data/local/Droidspaces/Containers/ 2>/dev/null
for c in debian-cli sb; do
  if [ -f "/data/local/Droidspaces/Containers/$c/container.config" ]; then
    pass "container.config exists: $c"
    grep -E '^(name|net_mode|use_sparse|static_nat|rootfs_path)=' \
      "/data/local/Droidspaces/Containers/$c/container.config" 2>/dev/null
  else
    fail "missing container.config: $c"
  fi
done

log "--- 3) running state ---"
"$DS" show 2>&1 || true

log "--- 4) start sb if stopped ---"
if ! "$DS" show 2>/dev/null | grep -qF 'sb'; then
  "$DS" --name=sb --rootfs-img=/data/local/Droidspaces/Containers/sb/rootfs.img \
    --hostname=sb --net=nat --nat-ip=172.28.1.3 start 2>&1 || true
  sleep 5
fi
if "$DS" show 2>/dev/null | grep -qF 'sb'; then
  pass "sb RUNNING"
else
  fail "sb not running"
fi

log "--- 5) sb in-container ping + curl ---"
if "$DS" --name=sb run ping -c 2 -W 3 1.1.1.1 2>&1 | grep -q "bytes from"; then
  pass "sb ping 1.1.1.1"
else
  fail "sb ping 1.1.1.1"
fi
if "$DS" --name=sb run sh -c 'curl -4 -sS -m 15 -o /dev/null -w "%{http_code}" https://deb.debian.org' 2>&1 | grep -qE '^200$'; then
  pass "sb curl deb.debian.org"
else
  "$DS" --name=sb run curl -4 -sS -m 15 -I https://deb.debian.org 2>&1 | tail -3
  fail "sb curl deb.debian.org"
fi

log "--- 6) debian-cli NAT if running ---"
if "$DS" show 2>/dev/null | grep -qE '\| debian-cli[[:space:]]+\|'; then
  if "$DS" --name=debian-cli run ping -c 2 -W 3 1.1.1.1 2>&1 | grep -q "bytes from"; then
    pass "debian-cli ping"
  else
    fail "debian-cli ping"
  fi
else
  log "[SKIP] debian-cli not running"
fi

log "--- 7) NAT uplink auto-detect (dmesg/log grep) ---"
grep -h "active uplink" /data/local/Droidspaces/Logs/droidspacesd.log 2>/dev/null | tail -3 || true
grep -h "Android routing" /data/local/Droidspaces/Logs/debian-cli/log \
  /data/local/Droidspaces/Logs/sb/log 2>/dev/null | tail -5 || true

log "--- 8) loop pool ---"
log "max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null)"
log "bound=$(losetup -a 2>/dev/null | wc -l)"

log "--- 9) sb stop/start x3 (loopfix dirty pool) ---"
i=1
while [ "$i" -le 3 ]; do
  "$DS" --name=sb stop 2>&1 | tail -1
  sleep 2
  "$DS" --name=sb start 2>&1 | tail -3
  sleep 4
  if "$DS" show 2>/dev/null | grep -qF 'sb'; then
    log "  round $i: OK"
  else
    fail "sb stop/start round $i"
    break
  fi
  i=$((i + 1))
done
[ "$FAIL" -eq 0 ] && pass "sb 3x stop/start"

log "LOG=$LOG"
log "========== RESULT: $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) =========="
exit "$FAIL"