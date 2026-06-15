#!/usr/bin/env bash
# Phase-2 gki_defconfig: only options that survive Bazel savedefconfig check.
# Other Droidspaces options go through tools/tb520fu_droidspaces_phase2_defconfig + --defconfig_fragment.
set -euo pipefail

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
DEF="$ROOT/common/arch/arm64/configs/gki_defconfig"

test -f "$DEF"

if grep -q '^CONFIG_BLK_DEV_LOOP_MIN_COUNT=' "$DEF"; then
  sed -i 's/^CONFIG_BLK_DEV_LOOP_MIN_COUNT=.*/CONFIG_BLK_DEV_LOOP_MIN_COUNT=64/' "$DEF"
else
  sed -i '/^CONFIG_BLK_DEV_LOOP=y$/a CONFIG_BLK_DEV_LOOP_MIN_COUNT=64' "$DEF"
fi

echo "=== phase-2 gki_defconfig (savedefconfig-safe) ==="
grep 'CONFIG_BLK_DEV_LOOP' "$DEF"