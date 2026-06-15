#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=repo_paths.sh
source "$SCRIPT_DIR/repo_paths.sh"
# shellcheck source=repo_bootstrap.sh
source "$SCRIPT_DIR/repo_bootstrap.sh"
[ -f "$SCRIPT_DIR/env.local" ] && source "$SCRIPT_DIR/env.local"

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
DEFCONFIG_FRAGMENT=//tb520fu:tb520fu_droidspaces_phase2_defconfig

ensure_minimal_diff_in_gki_tree

cd "$ROOT/common"
git checkout -- arch/arm64/configs/gki_defconfig include/linux/sched.h
git apply ../tb520fu-r13-droidspaces-minimal.diff
bash "$SCRIPT_DIR/apply_tb520fu_droidspaces_phase2_config.sh"
make ARCH=arm64 LLVM=1 mrproper >/dev/null 2>&1 || true

bash "$SCRIPT_DIR/setup_tb520fu_phase2_bazel_fragment.sh"

echo "=== gki_defconfig loop ==="
grep CONFIG_BLK_DEV_LOOP arch/arm64/configs/gki_defconfig

cd "$ROOT"
./tools/bazel build --config=local --jobs=2 --local_cpu_resources=2 --local_ram_resources=6144 \
  --defconfig_fragment="$DEFCONFIG_FRAGMENT" \
  //common:kernel_aarch64_config 2>&1 | tail -25

echo "=== built .config phase-2 options ==="
grep -E 'DEVTMPFS|IP_SET|TMPFS_XATTR|BLK_DEV_LOOP_MIN_COUNT|NETFILTER_XT_MATCH_ADDRTYPE|NETFILTER_XT_TARGET_REJECT|NETFILTER_XT_SET' \
  bazel-bin/common/kernel_aarch64_config/out_dir/.config