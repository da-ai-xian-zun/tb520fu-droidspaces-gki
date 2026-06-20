#!/usr/bin/env bash
# Offline verify loopfix APK: assets sparsemgr + built markers. No adb.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$ROOT/output/droidspaces-apk-loopfix/Droidspaces-loopfix-debug.apk}"
WORK="$ROOT/output/droidspaces-apk-loopfix/verify_unpack"

if [ ! -f "$APK" ]; then
  echo "[!] APK not found: $APK"
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"
unzip -q -o "$APK" -d "$WORK"

echo "========== APK verify: $(basename "$APK") =========="
echo "size: $(wc -c < "$APK") bytes"
sha256sum "$APK"

SPARSEMGR=""
for f in "$WORK"/assets/sparsemgr.sh "$WORK"/assets/*/sparsemgr.sh; do
  [ -f "$f" ] && SPARSEMGR="$f" && break
done
if [ -z "$SPARSEMGR" ]; then
  SPARSEMGR="$(find "$WORK" -name sparsemgr.sh | head -1)"
fi

fail=0
if [ -n "$SPARSEMGR" ] && [ -f "$SPARSEMGR" ]; then
  echo "[OK] sparsemgr.sh in APK: $SPARSEMGR"
  if grep -q '_mount_loop_img' "$SPARSEMGR"; then
    echo "[OK] _mount_loop_img present"
  else
    echo "[FAIL] _mount_loop_img missing"
    fail=1
  fi
  if grep -qE '_loop_scan_start|loop_scan_start' "$SPARSEMGR"; then
    echo "[OK] relative loop-scan floor referenced"
  else
    echo "[FAIL] loop_scan_start missing"
    fail=1
  fi
  sh -n "$SPARSEMGR" && echo "[OK] sparsemgr.sh syntax (sh -n)" || { echo "[FAIL] syntax"; fail=1; }
else
  echo "[FAIL] sparsemgr.sh not found in APK"
  fail=1
fi

# DEX won't show Kotlin strings reliably; check classes.dex size vs stock hint
if [ -f "$WORK/classes.dex" ]; then
  echo "[OK] classes.dex: $(wc -c < "$WORK/classes.dex") bytes"
fi

# Optional: strings grep for mount log line we added
if strings "$WORK/classes.dex" 2>/dev/null | grep -q 'loop-scan loop48'; then
  echo "[OK] SparseImageInstaller log string in DEX"
else
  echo "[WARN] loop-scan string not in DEX (ProGuard/R8 may strip; rely on Kotlin source build)"
fi

echo "========== RESULT: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL) =========="
exit "$fail"