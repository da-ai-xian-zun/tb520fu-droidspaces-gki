#!/usr/bin/env bash
# Build Droidspaces APK with sparse loop-scan patches (sparsemgr.sh + SparseImageInstaller.kt).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/Droidspaces-OSS"
ANDROID="$VENDOR/Android"
PATCH_SPARSEMGR="$ROOT/patches/sparsemgr-loop-scan.patch"
OUT="$ROOT/output/droidspaces-apk-loopfix"

if [ ! -d "$VENDOR/.git" ]; then
  echo "[!] Clone vendor: git clone https://github.com/ravindu644/Droidspaces-OSS.git $VENDOR"
  exit 1
fi

cd "$VENDOR"
BASE="$(git rev-parse HEAD)"
echo "[*] Vendor @ $BASE"

# sparsemgr.sh patch (idempotent via git apply --reverse check)
if ! grep -q '_mount_loop_img' Android/app/src/main/assets/sparsemgr.sh 2>/dev/null; then
  git apply "$PATCH_SPARSEMGR"
  echo "[+] Applied $PATCH_SPARSEMGR"
fi

assert_sh_lf() {
  local dir="$1" bad=0 f
  while IFS= read -r -d '' f; do
    if grep -q $'\r' "$f" 2>/dev/null; then
      echo "[!] CRLF in ${f#$dir/} — Android sh breaks on set -eu"
      bad=1
    fi
  done < <(find "$dir" -name '*.sh' -type f -print0)
  if [ "$bad" -ne 0 ]; then
    exit 1
  fi
  echo "[OK] asset *.sh are LF-only ($(find "$dir" -name '*.sh' -type f | wc -l | tr -d ' ') files)"
}

assert_sh_lf "$ANDROID/app/src/main/assets"

if [ ! -f Android/app/src/main/assets/mount_loop_scan.sh ]; then
  echo "[!] mount_loop_scan.sh missing in assets"
  exit 1
fi
if ! grep -q 'mount_loop_scan.sh' Android/app/src/main/java/com/droidspaces/app/util/SparseImageInstaller.kt; then
  echo "[!] SparseImageInstaller.kt missing mount_loop_scan.sh hook"
  exit 1
fi
if ! grep -q 'unmountSparseImage' Android/app/src/main/java/com/droidspaces/app/util/ContainerInstaller.kt; then
  echo "[!] ContainerInstaller.kt missing unmountSparseImage call — run: bash tools/apply_loopfix_vendor.sh"
  exit 1
fi

cd "$ANDROID"
if [ ! -f local.properties ]; then
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    echo "sdk.dir=${ANDROID_SDK_ROOT//\\/\/}" > local.properties
  elif [ -d "$HOME/AppData/Local/Android/Sdk" ]; then
    echo "sdk.dir=$HOME/AppData/Local/Android/Sdk" > local.properties
  else
    echo "[!] Create Android/local.properties with sdk.dir=..."
    exit 1
  fi
fi

export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
if [ ! -x "$JAVA_HOME/bin/java" ] && [ -x "/mnt/c/Program Files/Android/Android Studio/jbr/bin/java" ]; then
  export JAVA_HOME="/mnt/c/Program Files/Android/Android Studio/jbr"
fi

./gradlew assembleDebug --no-daemon

APK="$ANDROID/app/build/outputs/apk/debug/app-debug.apk"
mkdir -p "$OUT"
cp -f "$APK" "$OUT/Droidspaces-loopfix-debug.apk"
sha256sum "$OUT/Droidspaces-loopfix-debug.apk" | tee "$OUT/SHA256SUMS"
echo "[+] APK: $OUT/Droidspaces-loopfix-debug.apk"