#!/system/bin/sh
set -eu
DS=/data/local/Droidspaces/bin/droidspaces
i=1
while [ "$i" -le 3 ]; do
  echo "=== round $i stop ==="
  "$DS" --name=sb stop 2>&1 | tail -2
  sleep 2
  echo "=== round $i start ==="
  "$DS" --name=sb start 2>&1 | tail -3
  sleep 8
  if ! "$DS" show 2>/dev/null | grep -qF 'sb'; then
    echo "[FAIL] round $i not in show"
    exit 1
  fi
  echo "[OK] round $i RUNNING"
  ok=0
  j=1
  while [ "$j" -le 3 ]; do
    if "$DS" --name=sb run ping -c 1 -W 5 1.1.1.1 2>&1 | grep -q "bytes from"; then
      ok=1
      break
    fi
    sleep 3
    j=$((j + 1))
  done
  if [ "$ok" -eq 1 ]; then
    echo "[OK] round $i ping"
  else
    echo "[FAIL] round $i ping"
    exit 1
  fi
  i=$((i + 1))
done
echo "[PASS] sb 3x stop/start"