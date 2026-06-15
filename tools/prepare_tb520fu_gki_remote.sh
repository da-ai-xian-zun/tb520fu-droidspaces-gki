#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/tb520fu-gki}"
SYNC_JOBS="${SYNC_JOBS:-2}"
BUILD_JOBS="${BUILD_JOBS:-4}"
INSTALL_DEPS=0
RUN_SYNC=1
RUN_BUILD=0

KERNEL_MANIFEST_URL="https://android.googlesource.com/kernel/manifest"
KERNEL_MANIFEST_BRANCH="common-android14-6.1"
COMMON_URL="https://android.googlesource.com/kernel/common"
COMMON_TAG="android14-6.1.112_r00"
DROIDSPACES_URL="https://github.com/ravindu644/Droidspaces-OSS.git"
DROIDSPACES_REF="v6.3.0"

PATCH_DIR_REL="Documentation/resources/kernel-patches/GKI/below-kernel-6.12"
PATCH_123="001.GKI-below-6.12-fix_sysvipc_kabi_1_2_3.patch"
PATCH_345="001.GKI-below-6.12-fix_sysvipc_kabi_3_4_5.patch"
PATCH_678="001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch"
SELECTED_SYSVIPC_PATCH=""

SHA_123="bc3c1e8525fd232224211d5a0d0f216c4408d4042029a42d66131bd53174dfa3"
SHA_345="c47ff9ebb015430913058b3a08182b8c379812731613e1b23804eb6fa4e29ea4"
SHA_678="47fc945b2d73d9737d56c0f1c3a74cda0a95c30f9dc1b1abe546fa48940c4460"

usage() {
  cat <<'EOF'
Usage:
  prepare_tb520fu_gki_remote.sh [options]

Options:
  --workdir PATH       Work directory. Default: $HOME/tb520fu-gki
  --sync-jobs N        repo sync jobs. Default: 2
  --build-jobs N       build jobs written to helper. Default: 4
  --install-deps       apt install common build dependencies
  --no-sync            skip repo sync, only operate on existing tree
  --build              run low-resource build after patching
  -h, --help           show help

Default behavior does not run apt and does not build.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workdir) WORKDIR="$2"; shift 2 ;;
    --sync-jobs) SYNC_JOBS="$2"; shift 2 ;;
    --build-jobs) BUILD_JOBS="$2"; shift 2 ;;
    --install-deps) INSTALL_DEPS=1; shift ;;
    --no-sync) RUN_SYNC=0; shift ;;
    --build) RUN_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

run_low() {
  if command -v ionice >/dev/null 2>&1; then
    ionice -c2 -n7 nice -n 10 "$@"
  else
    nice -n 10 "$@"
  fi
}

require_cmds() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ "${#missing[@]}" -ne 0 ]; then
    echo "Missing commands: ${missing[*]}" >&2
    echo "Install manually, or rerun with --install-deps if this build container may use sudo apt." >&2
    exit 2
  fi
}

install_deps() {
  log "Installing dependencies via apt"
  sudo apt-get update
  sudo apt-get install -y \
    git curl ca-certificates python3 rsync unzip xz-utils lz4 cpio \
    build-essential bc bison flex libssl-dev libelf-dev dwarves pahole
}

print_host_state() {
  log "Host state"
  uname -a || true
  printf 'CPU: '; nproc || true
  printf 'Memory:\n'; free -h || true
  printf 'Disk:\n'; df -h "$WORKDIR" 2>/dev/null || df -h "$HOME" || true
}

ensure_repo_tool() {
  mkdir -p "$WORKDIR/bin"
  if command -v repo >/dev/null 2>&1; then
    REPO_BIN="$(command -v repo)"
    return
  fi
  REPO_BIN="$WORKDIR/bin/repo"
  if [ ! -x "$REPO_BIN" ]; then
    log "Downloading repo tool"
    curl -L --fail --retry 3 -o "$REPO_BIN" https://storage.googleapis.com/git-repo-downloads/repo
    chmod +x "$REPO_BIN"
  fi
}

sha256_file() {
  sha256sum "$1" | awk '{print tolower($1)}'
}

verify_sha() {
  local file="$1"
  local expected="$2"
  local got
  got="$(sha256_file "$file")"
  if [ "$got" != "$expected" ]; then
    echo "SHA256 mismatch for $file" >&2
    echo "expected: $expected" >&2
    echo "got:      $got" >&2
    exit 1
  fi
}

prepare_sources() {
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  if [ "$RUN_SYNC" -eq 1 ]; then
    ensure_repo_tool
    if [ ! -d .repo ]; then
      log "repo init: $KERNEL_MANIFEST_BRANCH"
      "$REPO_BIN" init -u "$KERNEL_MANIFEST_URL" -b "$KERNEL_MANIFEST_BRANCH" --partial-clone --clone-filter=blob:none
    fi

    log "repo sync with jobs=$SYNC_JOBS"
    run_low "$REPO_BIN" sync -c --fail-fast --no-clone-bundle --no-tags -j"$SYNC_JOBS"
  fi

  if [ ! -d common/.git ]; then
    echo "Missing $WORKDIR/common after sync." >&2
    exit 1
  fi

  log "Checkout common tag: $COMMON_TAG"
  git -C common fetch "$COMMON_URL" "refs/tags/$COMMON_TAG:refs/tags/$COMMON_TAG"
  git -C common checkout -B tb520fu-droidspaces "$COMMON_TAG"

  if [ ! -d droidspaces/.git ]; then
    log "Clone Droidspaces patches: $DROIDSPACES_REF"
    git clone --depth 1 --branch "$DROIDSPACES_REF" "$DROIDSPACES_URL" droidspaces
  else
    log "Update Droidspaces patches"
    git -C droidspaces fetch --depth 1 origin "$DROIDSPACES_REF"
    git -C droidspaces checkout -B "tb520fu-$DROIDSPACES_REF" FETCH_HEAD
  fi

  verify_sha "droidspaces/$PATCH_DIR_REL/$PATCH_123" "$SHA_123"
  verify_sha "droidspaces/$PATCH_DIR_REL/$PATCH_345" "$SHA_345"
  verify_sha "droidspaces/$PATCH_DIR_REL/$PATCH_678" "$SHA_678"
}

check_kabi_slots() {
  log "Inspect task_struct Android kABI slots"
  grep -n "saved_state\\|ANDROID_KABI_.*([1-8]" common/include/linux/sched.h | tee tb520fu-kabi-slots.txt

  if grep -q "ANDROID_KABI_USE(1,.*saved_state" common/include/linux/sched.h; then
    log "Slot 1 is occupied by saved_state. Do not use 1_2_3."
  else
    log "Slot 1 saved_state occupancy was not detected. Re-check manually before patching."
  fi
}

dry_run_patches() {
  local p123="droidspaces/$PATCH_DIR_REL/$PATCH_123"
  local p345="droidspaces/$PATCH_DIR_REL/$PATCH_345"
  local p678="droidspaces/$PATCH_DIR_REL/$PATCH_678"

  log "Dry-run SYSVIPC kABI patches"
  set +e
  git -C common apply --check "../$p123"
  local rc123=$?
  git -C common apply --check "../$p345"
  local rc345=$?
  git -C common apply --check "../$p678"
  local rc678=$?
  set -e

  {
    echo "patch dry-run results for $COMMON_TAG"
    echo "$PATCH_123: rc=$rc123"
    echo "$PATCH_345: rc=$rc345"
    echo "$PATCH_678: rc=$rc678"
    echo
    echo "Selection rule: use 3_4_5 if it applies cleanly; otherwise use 6_7_8. Never use 1_2_3 when slot 1 is occupied by saved_state."
  } | tee tb520fu-patch-dry-run.txt

  if [ "$rc345" -eq 0 ]; then
    SELECTED_SYSVIPC_PATCH="$PATCH_345"
  elif [ "$rc678" -eq 0 ]; then
    SELECTED_SYSVIPC_PATCH="$PATCH_678"
  else
    echo "Neither $PATCH_345 nor $PATCH_678 applied cleanly. Stop and inspect tb520fu-patch-dry-run.txt." >&2
    exit 1
  fi

  log "Selected SYSVIPC kABI patch: $SELECTED_SYSVIPC_PATCH"
}

apply_patch_and_config() {
  local selected="${SELECTED_SYSVIPC_PATCH:-$PATCH_345}"
  local p="../droidspaces/$PATCH_DIR_REL/$selected"

  log "Apply SYSVIPC kABI patch: $selected"
  if git -C common apply --reverse --check "$p" >/dev/null 2>&1; then
    log "Patch already applied"
  else
    git -C common apply "$p"
  fi

  log "Enable minimal Droidspaces options in gki_defconfig"
  (
    cd common
    scripts/config --file arch/arm64/configs/gki_defconfig \
      -e PID_NS \
      -e IPC_NS \
      -e SYSVIPC \
      -e POSIX_MQUEUE
  )

  git -C common diff -- include/linux/sched.h arch/arm64/configs/gki_defconfig > tb520fu-droidspaces-minimal.diff
}

write_helpers() {
  log "Write build helper and notes"
  cat > build_tb520fu_gki_low_resource.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"

export BUILD_CONFIG=common/build.config.gki.aarch64
export DIST_DIR="\$PWD/out/tb520fu-gki-6.1.112/dist"
export OUT_DIR="\$PWD/out/tb520fu-gki-6.1.112/out"
export MAKEFLAGS="-j$BUILD_JOBS"

mkdir -p "\$DIST_DIR" "\$OUT_DIR"

if command -v ionice >/dev/null 2>&1; then
  ionice -c2 -n7 nice -n 10 build/build.sh
else
  nice -n 10 build/build.sh
fi
EOF
  chmod +x build_tb520fu_gki_low_resource.sh

  cat > TB520FU-GKI-PREPARED.txt <<EOF
Prepared TB520FU Droidspaces GKI tree

Kernel common tag: $COMMON_TAG
Droidspaces ref:   $DROIDSPACES_REF
Selected patch:    ${SELECTED_SYSVIPC_PATCH:-$PATCH_345}
Fallback patch:    $PATCH_678
Forbidden first patch on 6.1.112: $PATCH_123

Changed files:
- common/include/linux/sched.h
- common/arch/arm64/configs/gki_defconfig

Diff:
- tb520fu-droidspaces-minimal.diff

Dry-run result:
- tb520fu-patch-dry-run.txt

kABI slot inspection:
- tb520fu-kabi-slots.txt

Build is not run by default. To build with low priority:
  ./build_tb520fu_gki_low_resource.sh

Keep this low on the PVE host:
- SYNC_JOBS=$SYNC_JOBS
- BUILD_JOBS=$BUILD_JOBS
- nice=10
- ionice best-effort 7 if available
EOF
}

main() {
  if [ "$INSTALL_DEPS" -eq 1 ]; then
    install_deps
  fi

  require_cmds git curl python3 sha256sum awk grep sed
  mkdir -p "$WORKDIR"
  print_host_state
  prepare_sources
  check_kabi_slots
  dry_run_patches
  apply_patch_and_config
  write_helpers

  if [ "$RUN_BUILD" -eq 1 ]; then
    log "Run low-resource build"
    run_low "$WORKDIR/build_tb520fu_gki_low_resource.sh"
  fi

  # Prefer canonical diff from this repo when cloned alongside GKI workdir.
  local repo_patch=""
  for candidate in \
    "$(dirname "$0")/../patches/tb520fu-r13-droidspaces-minimal.diff" \
    "$HOME/tb520fu-droidspaces-gki/patches/tb520fu-r13-droidspaces-minimal.diff"; do
    if [ -f "$candidate" ]; then
      repo_patch="$candidate"
      break
    fi
  done
  if [ -n "$repo_patch" ]; then
    log "Sync canonical minimal diff from repo"
    cp -f "$repo_patch" "$WORKDIR/tb520fu-r13-droidspaces-minimal.diff"
  fi

  log "Done: $WORKDIR"
}

main "$@"
