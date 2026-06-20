#!/system/bin/sh
# TB520FU: official App + loopfix CLI only (no魔改 APK assets).
set -u

DS=/data/local/Droidspaces/bin/droidspaces
LOG=/data/local/tmp/tb520fu_stock_app_loopfix_cli.log
FAIL=0

log() { echo "$@" | tee -a "$LOG"; }
pass() { log "[PASS] $1"; }
fail() { log "[FAIL] $1"; FAIL=1; }

: >"$LOG"
log "=== tb520fu stock App + loopfix CLI $(date) ==="
log "apk_bytes=$(wc -c <"$(pm path com.droidspaces.app 2>/dev/null | head -1 | cut -d: -f2)" 2>/dev/null || echo 0)"
log "cli_bytes=$(wc -c <"$DS") $(sha256sum "$DS" | awk '{print $1}')"
APK=$(pm path com.droidspaces.app 2>/dev/null | head -1 | cut -d: -f2)
if [ -n "$APK" ]; then
  log "apk_assets:"
  unzip -l "$APK" 2>/dev/null | grep -E 'mount_loop|sparsemgr|droidspaces-aarch64' | tee -a "$LOG" || true
fi

log "--- mount chain (stock SparseImageInstaller path) ---"
if sh /data/local/tmp/sparse_upstream_mount_chain.sh 2>&1 | tee -a "$LOG" | grep -q 'RESULT_upstream_chain: FAILED'; then
  pass "stock mount chain fails (expected on TB520FU)"
else
  fail "stock mount chain unexpected"
fi

log "--- debian-cli loopfix stop/start x5 ---"
ok=0
i=1
while [ "$i" -le 5 ]; do
  "$DS" --name=debian-cli stop 2>&1 | tail -1 | tee -a "$LOG"
  sleep 2
  "$DS" --name=debian-cli start 2>&1 | tail -2 | tee -a "$LOG"
  sleep 4
  if "$DS" show 2>/dev/null | grep -qF debian-cli; then
    ok=$((ok + 1))
  else
    fail "debian-cli round $i"
    break
  fi
  i=$((i + 1))
done
[ "$ok" -eq 5 ] && pass "debian-cli 5/5 stop/start"

log "max_loop=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null) bound=$(losetup -a 2>/dev/null | wc -l)"
log "=== RESULT: $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) ==="
exit "$FAIL"