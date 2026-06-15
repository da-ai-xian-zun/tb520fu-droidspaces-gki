#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
COMMON=$ROOT/common
CLANG=$ROOT/prebuilts/clang/host/linux-x86/clang-r487747c/bin
export PATH="$CLANG:/usr/bin:/bin"

cd "$COMMON"
git checkout -- arch/arm64/configs/gki_defconfig include/linux/sched.h
git apply ../tb520fu-r13-droidspaces-minimal.diff

make ARCH=arm64 LLVM=1 mrproper >/dev/null 2>&1 || true
make ARCH=arm64 LLVM=1 gki_defconfig

scripts/config --file .config \
  -e DEVTMPFS \
  -e NETFILTER_XT_MATCH_ADDRTYPE \
  -e NETFILTER_XT_TARGET_REJECT \
  -e NETFILTER_XT_TARGET_LOG \
  -e NETFILTER_XT_MATCH_RECENT \
  -e IP_SET \
  -e IP_SET_HASH_IP \
  -e IP_SET_HASH_NET \
  -e NETFILTER_XT_SET \
  -e TMPFS_POSIX_ACL \
  -e TMPFS_XATTR \
  --set-val BLK_DEV_LOOP_MIN_COUNT 64

make ARCH=arm64 LLVM=1 savedefconfig
make ARCH=arm64 LLVM=1 mrproper >/dev/null 2>&1 || true

git diff arch/arm64/configs/gki_defconfig > ../tb520fu-r13-droidspaces-phase2-gki_defconfig.diff
echo "Wrote ../tb520fu-r13-droidspaces-phase2-gki_defconfig.diff"
grep -E 'CONFIG_DEVTMPFS|CONFIG_BLK_DEV_LOOP_MIN_COUNT|CONFIG_IP_SET|CONFIG_TMPFS_XATTR' arch/arm64/configs/gki_defconfig