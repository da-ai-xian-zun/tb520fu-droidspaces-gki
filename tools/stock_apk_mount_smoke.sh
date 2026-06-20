#!/system/bin/sh
# After stock v6.3.0 APK is installed: verify stock installer mount chain fails on TB520FU.
set -eu

echo "=== stock_apk_mount_smoke $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
pm path com.droidspaces.app 2>/dev/null
wc -c /data/local/Droidspaces/bin/droidspaces /data/local/Droidspaces/bin/busybox 2>/dev/null || true
sha256sum /data/local/Droidspaces/bin/droidspaces 2>/dev/null || true

CHAIN=/data/local/tmp/sparse_upstream_mount_chain.sh
if [ ! -f "$CHAIN" ]; then
  echo "ERROR: push sparse_upstream_mount_chain.sh to /data/local/tmp first"
  exit 1
fi
chmod 755 "$CHAIN" 2>/dev/null || true

sh "$CHAIN"