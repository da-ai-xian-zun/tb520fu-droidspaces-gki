#!/usr/bin/env bash
# Build minimal Droidspaces GKI R13 (Image + system_dlkm) and pack boot_a for 9008 triplet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
# shellcheck source=repo_bootstrap.sh
source "$SCRIPT_DIR/repo_bootstrap.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
OUT="${OUT:-$HOME/tb520fu-boot-droidspaces-minimal-r13}"
STOCK_BOOT="${STOCK_BOOT:-}"
WIN_PKG="${WIN_PKG:-$WIN_PKG_MINIMAL}"
DROIDSPACES_REF="${DROIDSPACES_REF:-v6.3.0}"
PATCH="001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"
PATCH_DIR="Documentation/resources/kernel-patches/GKI/below-kernel-6.12"
PACK_BOOT="$SCRIPT_DIR/pack_boot_a_gki.sh"
PACK_TRIPLET="$SCRIPT_DIR/pack_tb520fu_droidspaces_triplet.sh"
BAZEL_JOBS="${BAZEL_JOBS:-2}"
BAZEL_CPU="${BAZEL_CPU:-2}"
BAZEL_RAM_MB="${BAZEL_RAM_MB:-6144}"

log() { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }

unset_all_proxy() {
  unset all_proxy ALL_PROXY http_proxy HTTP_PROXY https_proxy HTTPS_PROXY || true
}

ensure_droidspaces_patches() {
  cd "$ROOT"
  if [ ! -d droidspaces/.git ]; then
    log "Clone Droidspaces-OSS $DROIDSPACES_REF (direct, no proxy)"
    unset_all_proxy
    git clone --depth 1 --branch "$DROIDSPACES_REF" https://github.com/ravindu644/Droidspaces-OSS.git droidspaces
  else
    log "Update Droidspaces-OSS"
    unset_all_proxy
    git -C droidspaces fetch --depth 1 origin "$DROIDSPACES_REF"
    git -C droidspaces checkout -B "tb520fu-$DROIDSPACES_REF" FETCH_HEAD
  fi
  test -f "droidspaces/$PATCH_DIR/$PATCH"
}

apply_minimal_droidspaces() {
  ensure_minimal_diff_in_gki_tree
  cd "$ROOT/common"
  log "Reset common to clean R13 base"
  git checkout -- include/linux/sched.h arch/arm64/configs/gki_defconfig 2>/dev/null || true

  log "Apply verified minimal diff (kABI 6_7_8 + defconfig)"
  if git apply --reverse --check ../tb520fu-r13-droidspaces-minimal.diff >/dev/null 2>&1; then
    log "Minimal diff already applied"
  else
    git apply ../tb520fu-r13-droidspaces-minimal.diff
  fi

  grep -E 'CONFIG_SYSVIPC|CONFIG_POSIX_MQUEUE|CONFIG_PID_NS|CONFIG_NAMESPACES' arch/arm64/configs/gki_defconfig || true
}

build_dist() {
  cd "$ROOT"
  log "Bazel build //common:kernel_aarch64_dist"
  ./tools/bazel build --config=local \
    --jobs="$BAZEL_JOBS" \
    --local_cpu_resources="$BAZEL_CPU" \
    --local_ram_resources="$BAZEL_RAM_MB" \
    //common:kernel_aarch64_dist
}

main() {
  ensure_droidspaces_patches
  apply_minimal_droidspaces
  build_dist
  ROOT="$ROOT" OUT="$OUT" STOCK_BOOT="$STOCK_BOOT" bash "$PACK_BOOT"
  bash "$PACK_TRIPLET"
  log "Done. Outputs: $OUT/out and $WIN_PKG"
}

main "$@"