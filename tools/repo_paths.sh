#!/usr/bin/env bash
# Source from other scripts: source "$(dirname "$0")/repo_paths.sh"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export REPO_ROOT
export REPO_WSL="$REPO_ROOT"
export PATCHES_DIR="${PATCHES_DIR:-$REPO_ROOT/patches}"
export RELEASE_DIR="${RELEASE_DIR:-$REPO_ROOT/release}"
export WIN_PKG_MINIMAL="${WIN_PKG_MINIMAL:-$REPO_ROOT/packages/triplet-minimal}"
export WIN_PKG_PHASE2="${WIN_PKG_PHASE2:-$REPO_ROOT/packages/triplet-phase2}"