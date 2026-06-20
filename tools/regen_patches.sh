#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor/Droidspaces-OSS"
P="$ROOT/patches"

cp "$P/mount_loop_scan.sh" "$V/Android/app/src/main/assets/mount_loop_scan.sh"

for f in \
  "$V/src/mount.c" \
  "$V/Android/app/src/main/assets/sparsemgr.sh" \
  "$V/Android/app/src/main/assets/mount_loop_scan.sh" \
  "$V/Android/app/src/main/java/com/droidspaces/app/util/SparseImageInstaller.kt" \
  "$V/Android/app/src/main/java/com/droidspaces/app/util/ContainerInstaller.kt"; do
  sed -i $'s/\r$//' "$f"
done

cd "$V"
git diff 76cbd21 -- src/mount.c > "$P/droidspaces-android-loop-scan.patch"
git diff 76cbd21 -- Android/app/src/main/assets/sparsemgr.sh > "$P/sparsemgr-loop-scan.patch"
git diff 76cbd21 -- \
  Android/app/src/main/assets/mount_loop_scan.sh \
  Android/app/src/main/java/com/droidspaces/app/util/SparseImageInstaller.kt \
  > "$P/sparseimageinstaller-loop-scan.patch"
git diff 76cbd21 -- \
  Android/app/src/main/java/com/droidspaces/app/util/ContainerInstaller.kt \
  > "$P/sparseimageinstaller-unmount-after-config.patch"

echo "[*] diff stat:"
git diff 76cbd21 --stat
echo "[*] patch sizes:"
wc -l "$P"/*.patch