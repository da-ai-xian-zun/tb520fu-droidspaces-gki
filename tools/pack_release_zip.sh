#!/usr/bin/env bash
# Maintainer: pack GitHub Release zip (4 images + README; no flash scripts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
# shellcheck source=repo_bootstrap.sh
source "$SCRIPT_DIR/repo_bootstrap.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

VARIANT="${1:-phase2}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
ZIP_NAME="tb520fu-droidspaces-${VARIANT}-images.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

case "$VARIANT" in
  phase2)
    BUILD_OUT="${BUILD_OUT:-$HOME/tb520fu-boot-droidspaces-phase2-r13}"
    BOOT_IMG="${BOOT_IMG:-$BUILD_OUT/out/boot_a.img}"
    SUPER_IMG="${SUPER_IMG:-$BUILD_OUT/out/system_dlkm.ext4.resized-0xBA0000.img}"
    ;;
  minimal)
    BUILD_OUT="${BUILD_OUT:-$HOME/tb520fu-boot-droidspaces-minimal-r13}"
    BOOT_IMG="${BOOT_IMG:-$BUILD_OUT/out/boot_a.img}"
    SUPER_IMG="${SUPER_IMG:-$BUILD_OUT/out/system_dlkm.ext4.resized-0xBA0000.img}"
    ;;
  *)
    echo "Usage: pack_release_zip.sh [phase2|minimal]" >&2
    exit 2
    ;;
esac

INIT_BOOT_IMG_PATH="$(resolve_init_boot_flash)"
VBMETA_IMG="$(resolve_vbmeta_flash)"
test -f "$BOOT_IMG"
test -f "$SUPER_IMG"
test -f "$VBMETA_IMG"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -f "$INIT_BOOT_IMG_PATH" "$STAGING/init_boot_a.img"
cp -f "$BOOT_IMG" "$STAGING/boot_a.img"
cp -f "$SUPER_IMG" "$STAGING/super_5.img"
cp -f "$VBMETA_IMG" "$STAGING/vbmeta.img"
cp -f "$REPO_ROOT/release/README.txt" "$STAGING/"
cp -f "$REPO_ROOT/release/THIRD_PARTY_NOTICES.txt" "$STAGING/"
cp -f "$REPO_ROOT/release/init_boot_a.metadata.txt" "$STAGING/"

(
  cd "$STAGING"
  sha256sum init_boot_a.img boot_a.img super_5.img vbmeta.img > SHA256SUMS.txt
)

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"
if command -v zip >/dev/null 2>&1; then
  ( cd "$STAGING" && zip -r "$ZIP_PATH" . )
else
  echo "zip command not found; staging dir: $STAGING" >&2
  exit 1
fi

echo "Release zip: $ZIP_PATH"
ls -la "$ZIP_PATH"
echo "SHA256:"
sha256sum "$ZIP_PATH"