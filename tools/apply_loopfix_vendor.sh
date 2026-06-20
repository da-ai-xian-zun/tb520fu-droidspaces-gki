#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/Droidspaces-OSS"

cd "$V"
git checkout 76cbd21 -- \
  src/mount.c \
  Android/app/src/main/assets/sparsemgr.sh \
  Android/app/src/main/java/com/droidspaces/app/util/SparseImageInstaller.kt \
  Android/app/src/main/java/com/droidspaces/app/util/ContainerInstaller.kt
rm -f Android/app/src/main/assets/mount_loop_scan.sh

python3 "$ROOT/tools/apply_loopfix_vendor.py"
bash "$ROOT/tools/regen_patches.sh"

# Verify patches apply cleanly on fresh upstream
TMP=$(mktemp -d)
git worktree add --detach "$TMP" 76cbd21 >/dev/null
for patch in \
  droidspaces-android-loop-scan.patch \
  sparsemgr-loop-scan.patch \
  sparseimageinstaller-loop-scan.patch \
  sparseimageinstaller-unmount-after-config.patch; do
  echo "[*] check $patch"
  git -C "$TMP" apply --check "$ROOT/patches/$patch"
done
git worktree remove --force "$TMP" >/dev/null

echo "[OK] vendor patched; patches regenerated; git apply --check passed"