#!/usr/bin/env bash
# Build TB520FU loop-scan patched droidspaces (aarch64 static musl).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/Droidspaces-OSS"
PATCH="$ROOT/patches/droidspaces-android-loop-scan.patch"
OUT="$ROOT/output/droidspaces-loopfix"

if [ ! -d "$VENDOR/.git" ]; then
  echo "[!] Clone vendor first: git clone --depth 1 https://github.com/ravindu644/Droidspaces-OSS.git $VENDOR"
  exit 1
fi

cd "$VENDOR"

if ! command -v aarch64-linux-musl-gcc >/dev/null 2>&1; then
  TOOLCHAIN="$HOME/toolchains/aarch64-linux-musl-cross"
  if [ ! -x "$TOOLCHAIN/bin/aarch64-linux-musl-gcc" ]; then
    echo "[*] Downloading prebuilt musl toolchain from musl.cc..."
    mkdir -p "$HOME/toolchains"
    curl -fsSL https://musl.cc/aarch64-linux-musl-cross.tgz | tar -C "$HOME/toolchains" -xz
  fi
  export PATH="$TOOLCHAIN/bin:$PATH"
fi

make clean >/dev/null 2>&1 || true
make -j"$(nproc 2>/dev/null || echo 4)" aarch64 ENABLE_SOCKETD_BACKEND=1 \
  CC=aarch64-linux-musl-gcc \
  'CFLAGS=-Wall -Wextra -O2 -flto=auto -std=gnu99 -Isrc/include -no-pie -pthread -DDS_ENABLE_SOCKETD_BACKEND=1'

mkdir -p "$OUT"
cp -f output/droidspaces "$OUT/droidspaces-aarch64-loopfix"
sha256sum "$OUT/droidspaces-aarch64-loopfix" | tee "$OUT/SHA256SUMS"
file "$OUT/droidspaces-aarch64-loopfix"
echo "[+] Built: $OUT/droidspaces-aarch64-loopfix"