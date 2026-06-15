#!/usr/bin/env bash
# Stage developer flash package under packages/* (local build output, not GitHub Release).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
# shellcheck source=repo_bootstrap.sh
source "$SCRIPT_DIR/repo_bootstrap.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

WIN_PKG="${1:?WIN_PKG path required}"
BOOT_FINAL="${2:?boot_a.img path required}"
SYSTEM_DLKM_RESIZED="${3:?system_dlkm resized img path required}"

mkdir -p "$WIN_PKG/image" "$WIN_PKG/rollback"
cp -f "$BOOT_FINAL" "$WIN_PKG/image/boot_a.img"
cp -f "$SYSTEM_DLKM_RESIZED" "$WIN_PKG/image/super_5.img"
cp -f "$(resolve_vbmeta_flash)" "$WIN_PKG/image/vbmeta.img"

if [ -n "${PAIR_DIR:-}" ] && [ -d "$PAIR_DIR" ]; then
  [ -f "$PAIR_DIR/boot_a.stock-rollback.img" ] && cp -f "$PAIR_DIR/boot_a.stock-rollback.img" "$WIN_PKG/rollback/boot_a.img" || true
  if [ -f "$PAIR_DIR/system_dlkm.stock-rollback.img" ]; then
    cp -f "$PAIR_DIR/system_dlkm.stock-rollback.img" "$WIN_PKG/rollback/super_5.img"
  elif [ -f "$PAIR_DIR/system_dlkm.stock-rollback.ext4.img" ]; then
    cp -f "$PAIR_DIR/system_dlkm.stock-rollback.ext4.img" "$WIN_PKG/rollback/super_5.img"
  fi
  if [ -f "$PAIR_DIR/vbmeta.rollback.img" ]; then
    cp -f "$PAIR_DIR/vbmeta.rollback.img" "$WIN_PKG/rollback/vbmeta.img"
  elif [ -f "$PAIR_DIR/vbmeta.current-sukisu-rollback.img" ]; then
    cp -f "$PAIR_DIR/vbmeta.current-sukisu-rollback.img" "$WIN_PKG/rollback/vbmeta.img"
  fi
fi

if [ -n "${BASE9008_DIR:-}" ] && [ -f "$BASE9008_DIR/image/xbl_s_devprg_ns.melf" ]; then
  cp -f "$BASE9008_DIR/image/xbl_s_devprg_ns.melf" "$WIN_PKG/image/"
fi

( cd "$WIN_PKG" && sha256sum image/* rollback/* 2>/dev/null > SHA256SUMS.txt || sha256sum image/* > SHA256SUMS.txt )

echo "staged: $WIN_PKG/image/"
ls -la "$WIN_PKG/image/"