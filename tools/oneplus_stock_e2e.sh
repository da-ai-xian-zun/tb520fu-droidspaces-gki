#!/system/bin/sh
# OnePlus PKR110 stock stack E2E: manual container + agent install + agent lifecycle.
set -u

DS=/data/local/Droidspaces/bin/droidspaces
LOG=/data/local/tmp/oneplus_stock_e2e_$(date +%Y%m%d_%H%M%S).log
FAIL=0

log() { echo "$@" | tee -a "$LOG"; }
pass() { log "[PASS] $1"; }
fail() { log "[FAIL] $1"; FAIL=1; }

: >"$LOG"
log "========== OnePlus stock E2E $(date) =========="
log "CLI $(wc -c <"$DS") $(sha256sum "$DS" | awk '{print $1}')"
log "APK $(pm path com.droidspaces.app 2>/dev/null | head -1)"

log "--- A) manual container sb (user created) ---"
if [ -f /data/local/Droidspaces/Containers/sb/container.config ]; then
  pass "sb container.config exists"
  grep -E '^(name|use_sparse|sparse_image|rootfs_path|net_mode)=' \
    /data/local/Droidspaces/Containers/sb/container.config 2>/dev/null | tee -a "$LOG"
else
  fail "sb missing"
fi

if "$DS" show 2>/dev/null | grep -qF 'sb'; then
  pass "sb running (manual start)"
else
  fail "sb not running"
fi

log "--- A1) sb network ---"
if "$DS" --name=sb run ping -c 2 -W 8 1.1.1.1 2>&1 | grep -q "bytes from"; then
  pass "sb ping"
else
  fail "sb ping"
fi
if "$DS" --name=sb run sh -c 'curl -4 -sS -m 20 -o /dev/null -w "%{http_code}" https://deb.debian.org' 2>&1 | grep -qE '^200$'; then
  pass "sb curl"
else
  fail "sb curl"
fi

log "--- A2) agent CLI stop/start sb x3 ---"
i=1
while [ "$i" -le 3 ]; do
  "$DS" --name=sb stop 2>&1 | tail -1 | tee -a "$LOG"
  sleep 2
  "$DS" --name=sb start 2>&1 | tail -3 | tee -a "$LOG"
  sleep 6
  if "$DS" show 2>/dev/null | grep -qF 'sb'; then
    log "  agent restart round $i: OK"
  else
    fail "agent restart sb round $i"
    break
  fi
  i=$((i + 1))
done
[ "$FAIL" -eq 0 ] && pass "agent sb 3x stop/start"

log "--- A3) sb loop stress 10 ---"
if sh /data/local/tmp/loop_stress_named.sh sb 10 2>&1 | tee -a "$LOG" | grep -q 'ok=10 fail=0'; then
  pass "sb loop stress 10/10"
else
  fail "sb loop stress"
fi

log "--- B) agent install sb-auto (stock mount chain) ---"
if sh /data/local/tmp/oneplus_stock_agent_install.sh 2>&1 | tee -a "$LOG" | grep -q 'RESULT start: SUCCESS'; then
  pass "agent install+start sb-auto"
else
  fail "agent install sb-auto"
fi

log "--- B1) sb-auto loop stress 10 ---"
if sh /data/local/tmp/loop_stress_named.sh sb-auto 10 2>&1 | tee -a "$LOG" | grep -q 'ok=10 fail=0'; then
  pass "sb-auto loop stress 10/10"
else
  fail "sb-auto loop stress"
fi

log "--- cleanup sb-auto only ---"
"$DS" --name=sb-auto stop 2>/dev/null || true
rm -rf /data/local/Droidspaces/Containers/sb-auto
pass "sb-auto removed (sb kept)"

log "max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null) bound=$(losetup -a 2>/dev/null | wc -l)"
log "LOG=$LOG"
log "========== RESULT: $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) =========="
exit "$FAIL"