#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$ROOT/tb520fu"
FRAG="$PKG/tb520fu_droidspaces_phase2_defconfig"

mkdir -p "$PKG"
cp -f "$SCRIPT_DIR/tb520fu_droidspaces_phase2_defconfig" "$FRAG"

cat >"$PKG/BUILD.bazel" <<'EOF'
package(default_visibility = ["//visibility:public"])

exports_files(["tb520fu_droidspaces_phase2_defconfig"])
EOF

echo "Bazel fragment ready: //tb520fu:tb520fu_droidspaces_phase2_defconfig"