#!/bin/sh
# Scheme A: install Droidspaces APK + wait for backend + run check/smoke (host-side via adb)
# Usage: bash tools/xiaomi_scheme_a_install.sh <serial> [apk_path]
set -euo pipefail

SERIAL="${1:?usage: $0 <adb_serial> [apk_path]}"
APK="${2:-output/downloads/Droidspaces-v6.3.0.apk}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK_PATH="$ROOT/$APK"

if [ ! -f "$APK_PATH" ]; then
  echo "[!] APK not found: $APK_PATH"
  exit 1
fi

echo "[*] Installing APK on $SERIAL ..."
adb -s "$SERIAL" install -r "$APK_PATH"

echo "[*] Launch app (backend atomic install on first open) ..."
adb -s "$SERIAL" shell am start -n com.droidspaces.app/.MainActivity 2>/dev/null \
  || adb -s "$SERIAL" shell monkey -p com.droidspaces.app -c android.intent.category.LAUNCHER 1

echo "[*] Wait for backend (grant root if prompted on phone) ..."
for i in $(seq 1 30); do
  if adb -s "$SERIAL" shell su -c "test -x /data/local/Droidspaces/bin/droidspaces" 2>/dev/null; then
    echo "[+] Backend ready after ~${i}s"
    break
  fi
  sleep 2
done

adb -s "$SERIAL" shell su -c "ls -l /data/local/Droidspaces/bin/ 2>/dev/null || echo 'backend missing'"

echo "[*] droidspaces check ..."
adb -s "$SERIAL" shell su -c "/data/local/Droidspaces/bin/droidspaces check" || true

echo "[*] Push and run sparse_cli_app_compare (Droidspaces busybox) ..."
adb -s "$SERIAL" push "$ROOT/tools/sparse_cli_app_compare.sh" /data/local/tmp/
adb -s "$SERIAL" shell su -c "sh /data/local/tmp/sparse_cli_app_compare.sh" || true

echo "[*] Done. Review output above."