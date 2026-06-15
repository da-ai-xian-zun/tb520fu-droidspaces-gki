#!/usr/bin/env bash
ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
grep -E 'CONFIG_SYSVIPC|CONFIG_POSIX_MQUEUE|CONFIG_PID_NS|CONFIG_IPC_NS|CONFIG_NAMESPACES' \
  "$ROOT/common/arch/arm64/configs/gki_defconfig" || true
echo '--- diff ---'
git -C "$ROOT/common" diff arch/arm64/configs/gki_defconfig include/linux/sched.h | head -40