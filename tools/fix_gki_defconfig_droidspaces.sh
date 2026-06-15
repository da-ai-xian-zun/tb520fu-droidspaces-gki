#!/usr/bin/env bash
# DEPRECATED for Bazel GKI R13: manually adding CONFIG_PID_NS/IPC_NS to gki_defconfig
# breaks savedefconfig. Use tb520fu-r13-droidspaces-minimal.diff only.
echo "WARNING: This script breaks Bazel savedefconfig. Do not use for TB520FU R13." >&2
exit 1
set -euo pipefail
DEF="${1:-$HOME/tb520fu-gki-r13/common/arch/arm64/configs/gki_defconfig}"
sed -i '/^CONFIG_PID_NS=y$/d; /^CONFIG_IPC_NS=y$/d' "$DEF"
sed -i '/^CONFIG_PID_IN_CONTEXTIDR=y$/a CONFIG_PID_NS=y' "$DEF"
sed -i '/^CONFIG_INET_DIAG_DESTROY=y$/a CONFIG_IPC_NS=y' "$DEF"
grep -n 'CONFIG_SYSVIPC\|CONFIG_POSIX_MQUEUE\|CONFIG_PID_NS\|CONFIG_IPC_NS' "$DEF"