#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
OUT="${OUT:-$HOME/tb520fu-boot-droidspaces-minimal-r13}"
WIN_PKG="${WIN_PKG:-$WIN_PKG_MINIMAL}"
SYSTEM_DLKM_PARTITION_SIZE=12189696
PACK_BOOT="$SCRIPT_DIR/pack_boot_a_gki.sh"
STAGE="$SCRIPT_DIR/stage_triplet_package.sh"

bash "$PACK_BOOT"
boot_final="$OUT/out/boot_a.img"
image="$ROOT/bazel-bin/common/kernel_aarch64/Image"

src="$ROOT/bazel-bin/common/kernel_aarch64_images_system_dlkm_image/system_dlkm.img"
cp -f "$src" "$OUT/out/system_dlkm.ext4.img"
cp -f "$OUT/out/system_dlkm.ext4.img" "$OUT/out/system_dlkm.ext4.resized-0xBA0000.img"
truncate -s "$SYSTEM_DLKM_PARTITION_SIZE" "$OUT/out/system_dlkm.ext4.resized-0xBA0000.img"
sha256sum "$boot_final" "$image" "$OUT/out/system_dlkm.ext4.resized-0xBA0000.img" >"$OUT/out/SHA256SUMS.txt"

bash "$STAGE" "$WIN_PKG" "$boot_final" "$OUT/out/system_dlkm.ext4.resized-0xBA0000.img"

echo "kernel-version:"
cat "$OUT/out/kernel-version.txt"
echo "boot verify:"
cat "$OUT/out/boot_a.verify.txt"