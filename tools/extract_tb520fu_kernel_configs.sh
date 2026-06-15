#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/tb520fu-kernel-diff-20260614"
MK="$HOME/tb520fu-gki-r13/tools/mkbootimg"
EXTRACT="$HOME/tb520fu-gki-r13/common/scripts/extract-ikconfig"

: > "$ROOT/summary.tsv"

for img in "$ROOT"/*.img; do
  name="$(basename "$img" .img)"
  out="$ROOT/$name"
  rm -rf "$out"
  mkdir -p "$out"

  python3 "$MK/unpack_bootimg.py" --boot_img "$img" --out "$out/unpack" > "$out/unpack.txt"
  sha256sum "$img" > "$out/boot.sha256"

  if [ -f "$out/unpack/kernel" ]; then
    sha256sum "$out/unpack/kernel" > "$out/kernel.sha256"
    strings -a "$out/unpack/kernel" | grep -m1 'Linux version ' > "$out/linux-version.txt" || true
    "$EXTRACT" "$out/unpack/kernel" > "$out/ikconfig.txt" 2> "$out/ikconfig.err" || true
    cfg_lines="$(wc -l < "$out/ikconfig.txt" 2>/dev/null || echo 0)"
    boot_sha="$(cut -d' ' -f1 "$out/boot.sha256")"
    kernel_sha="$(cut -d' ' -f1 "$out/kernel.sha256")"
    version="$(cat "$out/linux-version.txt" 2>/dev/null || true)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$boot_sha" "$kernel_sha" "$cfg_lines" "$version" >> "$ROOT/summary.tsv"
  fi
done

cat "$ROOT/summary.tsv"
