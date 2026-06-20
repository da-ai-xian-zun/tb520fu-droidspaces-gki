#!/system/bin/sh
# Dirty-pool rescue: stock CLI fails warmup -> loopfix should succeed (no reboot).
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
STOCK=/data/local/Droidspaces/bin/droidspaces.bak.pre-loopfix
LOOPFIX_BAK=/data/local/Droidspaces/bin/droidspaces.loopfix-rescue-test.bak
NAME="${1:-debian-cli}"

echo "=== loopfix_dirty_pool_rescue $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
echo "container=$NAME"
echo -n "bound: "; losetup -a 2>/dev/null | wc -l

restore() {
  if [ -f "$LOOPFIX_BAK" ]; then
    cp -f "$LOOPFIX_BAK" "$DS"
    chmod 755 "$DS"
    echo "restored loopfix ($(wc -c < "$DS") B)"
  fi
}
trap restore EXIT INT TERM

"$DS" --name="$NAME" stop 2>/dev/null || true
sleep 2

cp -f "$DS" "$LOOPFIX_BAK"
cp -f "$STOCK" "$DS"
chmod 755 "$DS"
echo "using stock CLI ($(wc -c < "$DS") B)"

echo "--- stock warmup ---"
if "$DS" --name="$NAME" start 2>&1 | tee /data/local/tmp/rescue-stock.log; then
  sleep 3
  if "$DS" show 2>/dev/null | grep -q "$NAME"; then
    echo "RESULT stock_warmup: SUCCESS (pool not dirty enough)"
    "$DS" --name="$NAME" stop 2>/dev/null || true
    restore
    trap - EXIT INT TERM
    exit 0
  fi
fi
echo "RESULT stock_warmup: FAILED (expected if dirty)"

cp -f "$LOOPFIX_BAK" "$DS"
chmod 755 "$DS"
echo "--- loopfix warmup (no reboot) ---"
out=$("$DS" --name="$NAME" start 2>&1) || true
echo "$out"
sleep 4
if "$DS" show 2>/dev/null | grep -q "$NAME"; then
  echo "RESULT loopfix_rescue: SUCCESS"
  "$DS" --name="$NAME" stop 2>/dev/null || true
  restore
  trap - EXIT INT TERM
  exit 0
else
  echo "RESULT loopfix_rescue: FAILED"
  restore
  trap - EXIT INT TERM
  exit 1
fi