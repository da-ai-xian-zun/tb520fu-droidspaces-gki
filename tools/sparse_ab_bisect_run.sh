#!/system/bin/sh
# Reverse bisect: all nonessential OFF, enable ONE module at a time (caller reboots between)
set -u
LOG=/data/local/tmp/sparse_ab_bisect.log
MARKER=/data/local/tmp/sparse_ab_disabled_modules.list

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

run_smoke() {
  sh /data/local/tmp/sparse_ab_module_isolate.sh smoke 2>&1 | grep -E 'RESULT|LOOP_SET|Failed|losetup:.*open files' || true
}

case "${1:-}" in
  init)
    sh /data/local/tmp/sparse_ab_module_isolate.sh disable-nonessential
    log "INIT all nonessential disabled — REBOOT NOW"
    ;;
  baseline)
    log "BASELINE (only droidspaces+zygisk)"
    run_smoke | tee -a "$LOG"
    ;;
  test-one)
    id="$2"
    [ -n "$id" ] || exit 1
    if [ -f "$MARKER" ]; then
      while read -r x; do
        [ -n "$x" ] && touch "/data/adb/modules/$x/disable"
      done < "$MARKER"
    fi
    rm -f "/data/adb/modules/$id/disable"
    log "ENABLED ONLY: $id (others off) — REBOOT then: bisect-run smoke $id"
    ;;
  smoke)
    label="${2:-unknown}"
    log "SMOKE with $label"
    run_smoke | tee -a "$LOG"
    ;;
  finish)
    sh /data/local/tmp/sparse_ab_module_isolate.sh restore
    log "FINISH restored all — REBOOT NOW"
    ;;
  *)
    echo "usage: $0 {init|baseline|test-one ID|smoke LABEL|finish}"
    ;;
esac