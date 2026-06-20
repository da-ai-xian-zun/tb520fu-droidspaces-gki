#!/system/bin/sh
# Safely test stock CLI dirty-pool stop/start on a named sparse container.
# Swaps loopfix -> stock for the test, then restores loopfix from backup.
# Usage: stock_cli_dirty_pool_test.sh [container] [max_rounds]
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
BACKUP=/data/local/Droidspaces/bin/droidspaces.loopfix.bak
STOCK_SRC="${STOCK_SRC:-}"
NAME="${1:-debian-cli}"
MAX_ROUNDS="${2:-25}"

STOCK_SIZE=461544
LOOPFIX_SIZE=410168

if [ -z "$STOCK_SRC" ] || [ ! -f "$STOCK_SRC" ]; then
  for c in \
    /data/local/Droidspaces/bin/droidspaces.bak.pre-loopfix \
    /data/local/tmp/droidspaces-stock \
    /data/local/tmp/droidspaces-aarch64; do
    if [ -f "$c" ] && [ "$(wc -c < "$c")" -eq "$STOCK_SIZE" ]; then
      STOCK_SRC="$c"
      break
    fi
  done
fi

if [ -z "$STOCK_SRC" ] || [ ! -f "$STOCK_SRC" ]; then
  echo "ERROR: stock CLI (461544 B) not found. Push to /data/local/tmp/droidspaces-stock"
  exit 1
fi

echo "=== stock_cli_dirty_pool_test $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
echo "container=$NAME max_rounds=$MAX_ROUNDS"
getprop ro.product.model
uname -r
echo -n "max_loop: "; cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "?"
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l
echo "stock_src: $STOCK_SRC ($(wc -c < "$STOCK_SRC") B)"

if [ ! -f "$DS" ]; then
  echo "ERROR: $DS missing"
  exit 1
fi

CUR_SIZE=$(wc -c < "$DS")
echo "current CLI: $CUR_SIZE B"

# Ensure container stopped before binary swap
"$DS" --name="$NAME" stop 2>/dev/null || true
sleep 2

# Backup loopfix if present
if [ "$CUR_SIZE" -eq "$LOOPFIX_SIZE" ]; then
  cp -f "$DS" "$BACKUP"
  echo "backed up loopfix -> $BACKUP"
elif [ -f "$BACKUP" ]; then
  echo "loopfix backup already at $BACKUP"
else
  cp -f "$DS" "$BACKUP"
  echo "backed up current CLI -> $BACKUP"
fi

restore_cli() {
  if [ -f "$BACKUP" ]; then
    cp -f "$BACKUP" "$DS"
    chmod 755 "$DS"
    echo "restored CLI from $BACKUP ($(wc -c < "$DS") B)"
  fi
}
trap restore_cli EXIT INT TERM

cp -f "$STOCK_SRC" "$DS"
chmod 755 "$DS"
echo "installed stock CLI ($(wc -c < "$DS") B)"

# Warm-up start
echo "--- warmup start ---"
if ! "$DS" --name="$NAME" start 2>&1; then
  echo "ERROR: warmup start failed on stock CLI"
  exit 1
fi
sleep 4
if ! "$DS" show 2>/dev/null | grep -q "$NAME"; then
  echo "ERROR: container not running after warmup"
  exit 1
fi
echo "warmup: OK"

ok=0
fail=0
fail_round=0

i=1
while [ "$i" -le "$MAX_ROUNDS" ]; do
  echo "--- round $i/$MAX_ROUNDS ---"
  echo -n "  bound before: "; losetup -a 2>/dev/null | wc -l
  "$DS" --name="$NAME" stop 2>&1 || true
  sleep 2
  out=$("$DS" --name="$NAME" start 2>&1) || true
  sleep 4
  if "$DS" show 2>/dev/null | grep -q "$NAME"; then
    echo "  RESULT round $i: SUCCESS"
    ok=$i
  else
    echo "  RESULT round $i: FAILED"
    fail=1
    fail_round=$i
    echo "$out" | tail -12
    echo "$out" | grep -qiE 'LOOP_SET_FD|LOOP_CTL|Resource busy|loop device|Failed to attach' && echo "  (loop-related failure)"
    break
  fi
  i=$((i + 1))
done

echo "========== SUMMARY =========="
echo "last_ok_round=$ok"
echo "first_fail_round=${fail_round:-none}"
echo "completed_without_fail=$([ "$fail" -eq 0 ] && echo yes || echo no)"
echo "============================="