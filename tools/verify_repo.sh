#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"

fail=0
ok() { printf 'OK  %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fail=1; }

echo "=== TB520FU Droidspaces GKI repo verify ==="

if [ -f "$PATCHES_DIR/tb520fu-r13-droidspaces-minimal.diff" ]; then ok "patches/minimal.diff"; else bad "missing minimal.diff"; fi
for f in README.txt THIRD_PARTY_NOTICES.txt; do
  [ -f "$RELEASE_DIR/$f" ] && ok "release/$f" || bad "missing release/$f"
done
[ ! -f "$RELEASE_DIR/flash.cmd" ] && ok "release has no flash.cmd" || bad "release/flash.cmd should be removed"
[ -f "$REPO_ROOT/docs/MANUAL_FLASH.md" ] && ok "docs/MANUAL_FLASH.md" || bad "missing MANUAL_FLASH.md"
[ -f "$REPO_ROOT/release/init_boot_a.metadata.txt" ] && ok "release/init_boot_a.metadata.txt" || bad "missing init_boot metadata"
[ -f "$REPO_ROOT/packages/triplet-phase2/rawprogram_release_quad.xml" ] && ok "rawprogram_release_quad.xml" || bad "missing quad xml"
[ -f "$REPO_ROOT/docs/COMPLIANCE.md" ] && ok "docs/COMPLIANCE.md" || bad "missing COMPLIANCE.md"

if find "$REPO_ROOT" -name '*.img' ! -path '*/packages/*' 2>/dev/null | grep -q .; then
  bad "stray *.img in repo"
else
  ok "no stray *.img"
fi

for sh in build_tb520fu_droidspaces_phase2.sh pack_release_zip.sh; do
  [ -f "$SCRIPT_DIR/$sh" ] && ok "tools/$sh" || bad "missing tools/$sh"
done

[ "$fail" -eq 0 ] && echo "=== All checks passed ===" || { echo "=== FAILED ===" >&2; exit 1; }