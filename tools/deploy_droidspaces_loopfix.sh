#!/system/bin/sh
# Deploy loop-scan patched droidspaces binary (run from adb as root).
set -u

BIN="${1:-/data/local/tmp/droidspaces-loopfix}"
DST=/data/local/Droidspaces/bin/droidspaces
BAK="${DST}.bak.pre-loopfix"

if [ ! -f "$BIN" ]; then
  echo "ERROR: patched binary not found: $BIN"
  exit 1
fi

chmod 755 "$BIN"
"$BIN" --version 2>/dev/null || "$BIN" check 2>/dev/null || true

if [ -x "$DST" ] && [ ! -f "$BAK" ]; then
  cp -a "$DST" "$BAK"
  echo "Backed up original to $BAK"
fi

cp -f "$BIN" "$DST"
chmod 755 "$DST"
chcon u:object_r:system_file:s0 "$DST" 2>/dev/null || true

echo "Deployed loopfix droidspaces to $DST"
"$DST" check 2>&1 | head -20