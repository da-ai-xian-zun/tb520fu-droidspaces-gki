#!/usr/bin/env bash
# Source after repo_paths.sh

ensure_minimal_diff_in_gki_tree() {
  local root="${ROOT:-$HOME/tb520fu-gki-r13}"
  local dst="$root/tb520fu-r13-droidspaces-minimal.diff"
  local src="$PATCHES_DIR/tb520fu-r13-droidspaces-minimal.diff"
  if [ ! -f "$dst" ]; then
    if [ -f "$src" ]; then
      cp -f "$src" "$dst"
    else
      echo "Missing kernel diff: $src" >&2
      echo "Run: bash tools/prepare_tb520fu_gki_remote.sh" >&2
      return 1
    fi
  fi
}

resolve_init_boot_flash() {
  local img="${INIT_BOOT_IMG:-}"
  if [ -z "$img" ] || [ ! -f "$img" ]; then
    echo "INIT_BOOT_IMG must point to SukiSU-patched init_boot_a.img (see tools/env.example)" >&2
    return 1
  fi
  echo "$img"
}

resolve_vbmeta_flash() {
  local pair="${PAIR_DIR:-}"
  if [ -z "$pair" ] || [ ! -d "$pair" ]; then
    echo "PAIR_DIR must point to vbmeta backup (see tools/env.example)" >&2
    return 1
  fi
  if [ -f "$pair/vbmeta.hashtree-disabled.img" ]; then
    echo "$pair/vbmeta.hashtree-disabled.img"
  elif [ -f "$pair/vbmeta.current-sukisu-hashtree-disabled.img" ]; then
    echo "$pair/vbmeta.current-sukisu-hashtree-disabled.img"
  else
    echo "Missing vbmeta in PAIR_DIR: $pair" >&2
    return 1
  fi
}