#!/system/bin/sh
# Install TB520FU loop-scan droidspaces and keep it across App binary refreshes.
set -u

LOOPFIX_SRC="${1:-/data/local/tmp/droidspaces-loopfix}"
BIN_DIR=/data/local/Droidspaces/bin
ACTIVE="$BIN_DIR/droidspaces"
STORE="$BIN_DIR/droidspaces.loopfix"
HOOK="$BIN_DIR/apply-loopfix.sh"
MARKER="$BIN_DIR/.loopfix-enabled"

if [ ! -f "$LOOPFIX_SRC" ]; then
  echo "ERROR: missing $LOOPFIX_SRC"
  exit 1
fi

mkdir -p "$BIN_DIR"
cp -f "$LOOPFIX_SRC" "$STORE"
cp -f "$LOOPFIX_SRC" "$ACTIVE"
chmod 755 "$STORE" "$ACTIVE"
chcon u:object_r:droidspacesd_exec:s0 "$STORE" 2>/dev/null || \
  chcon u:object_r:system_file:s0 "$STORE" 2>/dev/null || true
chcon u:object_r:droidspacesd_exec:s0 "$ACTIVE" 2>/dev/null || \
  chcon u:object_r:system_file:s0 "$ACTIVE" 2>/dev/null || true

cat > "$HOOK" << 'EOF'
#!/system/bin/sh
# Re-apply loopfix if App overwrote droidspaces with stock binary.
STORE=/data/local/Droidspaces/bin/droidspaces.loopfix
ACTIVE=/data/local/Droidspaces/bin/droidspaces
MARKER=/data/local/Droidspaces/bin/.loopfix-enabled
[ -f "$MARKER" ] || exit 0
[ -f "$STORE" ] || exit 0
# Stock ~461544 bytes; loopfix ~410168 bytes
if [ "$(wc -c < "$ACTIVE" 2>/dev/null || echo 0)" != "$(wc -c < "$STORE" 2>/dev/null || echo 1)" ]; then
  cp -f "$STORE" "$ACTIVE"
  chmod 755 "$ACTIVE"
  chcon u:object_r:droidspacesd_exec:s0 "$ACTIVE" 2>/dev/null || true
fi
EOF
chmod 755 "$HOOK"
touch "$MARKER"

# Hook into KSU droidspaces module service (if present)
MOD=/data/adb/modules/droidspaces
if [ -d "$MOD" ]; then
  if ! grep -q 'apply-loopfix.sh' "$MOD/service.sh" 2>/dev/null; then
    echo 'sh /data/local/Droidspaces/bin/apply-loopfix.sh' >> "$MOD/service.sh"
  fi
fi

# Apply now + restart daemon
sh "$HOOK"
pkill -9 -f 'droidspaces daemon' 2>/dev/null || true
sleep 1
"$ACTIVE" daemon >/dev/null 2>&1 &
sleep 2

echo "loopfix installed: $(wc -c < "$ACTIVE") bytes"
"$ACTIVE" check 2>&1 | grep -E 'Loop device|Summary' || true