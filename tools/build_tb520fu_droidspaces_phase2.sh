#!/usr/bin/env bash
# Build Droidspaces GKI R13 phase-2 (minimal kABI + full recommended defconfig + max_loop cmdline pack).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
# shellcheck source=repo_bootstrap.sh
source "$SCRIPT_DIR/repo_bootstrap.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
OUT="${OUT:-$HOME/tb520fu-boot-droidspaces-phase2-r13}"
STOCK_BOOT="${STOCK_BOOT:-}"
WIN_PKG="${WIN_PKG:-$WIN_PKG_PHASE2}"
BOOT_CMDLINE="${BOOT_CMDLINE:-max_loop=64}"
DROIDSPACES_REF="${DROIDSPACES_REF:-v6.3.0}"
PATCH="001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"
PATCH_DIR="Documentation/resources/kernel-patches/GKI/below-kernel-6.12"
SYSTEM_DLKM_PARTITION_SIZE=12189696
BAZEL_JOBS="${BAZEL_JOBS:-2}"
BAZEL_CPU="${BAZEL_CPU:-2}"
BAZEL_RAM_MB="${BAZEL_RAM_MB:-6144}"

APPLY_PHASE2="$SCRIPT_DIR/apply_tb520fu_droidspaces_phase2_config.sh"
PACK_BOOT="$SCRIPT_DIR/pack_boot_a_gki.sh"
PACK_TRIPLET="$SCRIPT_DIR/pack_tb520fu_droidspaces_phase2_triplet.sh"
SETUP_FRAGMENT="$SCRIPT_DIR/setup_tb520fu_phase2_bazel_fragment.sh"
DEFCONFIG_FRAGMENT="//tb520fu:tb520fu_droidspaces_phase2_defconfig"

log() { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }

unset_all_proxy() {
  unset all_proxy ALL_PROXY http_proxy HTTP_PROXY https_proxy HTTPS_PROXY || true
}

ensure_droidspaces_patches() {
  cd "$ROOT"
  if [ ! -d droidspaces/.git ]; then
    log "Clone Droidspaces-OSS $DROIDSPACES_REF"
    unset_all_proxy
    git clone --depth 1 --branch "$DROIDSPACES_REF" https://github.com/ravindu644/Droidspaces-OSS.git droidspaces
  fi
  test -f "droidspaces/$PATCH_DIR/$PATCH"
}

apply_droidspaces_tree() {
  ensure_minimal_diff_in_gki_tree
  cd "$ROOT/common"
  log "Reset + apply minimal kABI diff"
  git checkout -- include/linux/sched.h arch/arm64/configs/gki_defconfig 2>/dev/null || true
  if git apply --reverse --check ../tb520fu-r13-droidspaces-minimal.diff >/dev/null 2>&1; then
    log "Minimal diff already applied"
  else
    git apply ../tb520fu-r13-droidspaces-minimal.diff
  fi
  log "Apply phase-2 defconfig options"
  bash "$APPLY_PHASE2"
}

clean_common_tree() {
  cd "$ROOT/common"
  log "mrproper common (Bazel requires clean source tree)"
  make ARCH=arm64 LLVM=1 mrproper >/dev/null 2>&1 || true
}

build_dist() {
  clean_common_tree
  bash "$SETUP_FRAGMENT"
  cd "$ROOT"
  log "Bazel build //common:kernel_aarch64_dist (defconfig_fragment=$DEFCONFIG_FRAGMENT)"
  ./tools/bazel build --config=local \
    --jobs="$BAZEL_JOBS" \
    --local_cpu_resources="$BAZEL_CPU" \
    --local_ram_resources="$BAZEL_RAM_MB" \
    --defconfig_fragment="$DEFCONFIG_FRAGMENT" \
    //common:kernel_aarch64_dist
}

pack_and_stage() {
  log "Pack boot_a (cmdline: $BOOT_CMDLINE)"
  ROOT="$ROOT" OUT="$OUT" STOCK_BOOT="$STOCK_BOOT" BOOT_CMDLINE="$BOOT_CMDLINE" bash "$PACK_BOOT"
  bash "$PACK_TRIPLET"
}

main() {
  ensure_droidspaces_patches
  apply_droidspaces_tree
  build_dist
  pack_and_stage
  log "Done. Outputs: $OUT/out and $WIN_PKG"
}

main "$@"