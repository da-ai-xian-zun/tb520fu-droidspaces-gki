#!/system/bin/sh
# Stress debian-cli sparse stop/start without reboot — detect LOOP_SET_FD
set -u

DS=/data/local/Droidspaces/bin/droidspaces
NAME=debian-cli
ROUNDS="${1:-5}"

ok=0
fail=0

echo "========== LOOP STRESS ($ROUNDS rounds, no reboot) =========="
echo -n "max_loop: "; cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "?"
echo -n "losetup bound: "; losetup -a 2>/dev/null | wc -l

i=1
while [ "$i" -le "$ROUNDS" ]; do
  echo "--- round $i/$ROUNDS ---"
  echo -n "  bound before: "; losetup -a 2>/dev/null | wc -l
  out=$("$DS" --name="$NAME" stop 2>&1) || true
  sleep 2
  out=$("$DS" --name="$NAME" start 2>&1) || true
  sleep 4
  if "$DS" show 2>/dev/null | grep -q "$NAME"; then
    echo "  RESULT round $i: SUCCESS"
    ok=$((ok + 1))
  else
    echo "  RESULT round $i: FAILED"
    echo "$out" | tail -5
    fail=$((fail + 1))
    echo "$out" | grep -qiE 'LOOP_SET_FD|LOOP_CTL|Resource busy' && echo "  (loop ioctl failure)"
    break
  fi
  i=$((i + 1))
done

echo "========== SUMMARY: ok=$ok fail=$fail =========="
[ "$fail" -eq 0 ]