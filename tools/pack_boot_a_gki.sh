#!/usr/bin/env bash
# Pack a GKI boot_a.img with testkey + partition padding, matching tb520fu-boot-r13 workflow.
set -euo pipefail

ROOT="${ROOT:-$HOME/tb520fu-gki-r13}"
OUT="${OUT:-$HOME/tb520fu-boot-droidspaces-minimal-r13}"
KERNEL_IMAGE="${KERNEL_IMAGE:-$ROOT/bazel-bin/common/kernel_aarch64/Image}"
STOCK_BOOT="${STOCK_BOOT:-}"
BOOT_PARTITION_SIZE=100663296
BOOT_CMDLINE="${BOOT_CMDLINE:-}"
MKBOOTIMG="$ROOT/tools/mkbootimg"
AVBTOOL="$ROOT/prebuilts/kernel-build-tools/linux-x86/bin/avbtool"
TESTKEY="$MKBOOTIMG/gki/testdata/testkey_rsa4096.pem"
GKI_INFO="${GKI_INFO:-$ROOT/out/bazel/output_user_root/cace636ffb141155027360b1219160e3/execroot/__main__/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_gki_artifacts/gki-info.txt}"

export PATH="$(dirname "$AVBTOOL"):/usr/bin:/bin:${PATH:-}"

AVB_FOOTER_ARGS=(
  --partition_name boot
  --partition_size "$BOOT_PARTITION_SIZE"
  --algorithm SHA256_RSA4096
  --key "$TESTKEY"
  --rollback_index 1762300800
  --prop com.android.build.boot.os_version:14
  --prop com.android.build.boot.fingerprint:Lenovo/TB520FU/TB520FU:14/UKQ1.240826.001/ZUI_17.5.10.096_251127_ROW:user/release-keys
  --prop com.android.build.boot.security_patch:2025-10-05
)

mkdir -p "$OUT/out"
test -f "$KERNEL_IMAGE"
if [ -z "$STOCK_BOOT" ] || [ ! -f "$STOCK_BOOT" ]; then
  echo "STOCK_BOOT must point to stock boot_a.img (see tools/env.example)" >&2
  exit 1
fi
test -f "$AVBTOOL"
test -f "$TESTKEY"

kernel_release="$(strings -a "$KERNEL_IMAGE" | grep -m1 'Linux version ' | sed -n 's/.*Linux version \([^ ]*\).*/\1/p' || true)"
kernel_release="${kernel_release:-6.1.112-android14-11-maybe-dirty}"

empty_rd="$OUT/out/empty-ramdisk"
boot_nosig="$OUT/out/boot-droidspaces-nosig.img"
boot_cert="$OUT/out/boot-droidspaces-certified.img"
boot_final="$OUT/out/boot_a.img"

: >"$empty_rd"
mkbootimg_args=(--header_version 4 --pagesize 4096 --kernel "$KERNEL_IMAGE" --ramdisk "$empty_rd")
if [ -n "$BOOT_CMDLINE" ]; then
  mkbootimg_args+=(--cmdline "$BOOT_CMDLINE")
fi
python3 "$MKBOOTIMG/mkbootimg.py" "${mkbootimg_args[@]}" -o "$boot_nosig"

gki_info_args=()
if [ -f "$GKI_INFO" ]; then
  gki_info_args=(--gki_info "$GKI_INFO")
fi

cd "$MKBOOTIMG"
PYTHONPATH=. python3 gki/certify_bootimg.py \
  --boot_img "$boot_nosig" \
  --algorithm SHA256_RSA4096 \
  --key "$TESTKEY" \
  -o "$boot_cert" \
  "${gki_info_args[@]}" \
  --extra_args "--prop ARCH:arm64 --prop BRANCH: --prop KERNEL_RELEASE:$kernel_release" \
  --extra_footer_args "${AVB_FOOTER_ARGS[*]}"

# certify_bootimg uses --dynamic_partition_size when input has no footer; re-sign with fixed partition padding.
cp -f "$boot_cert" "$boot_final"
"$AVBTOOL" erase_footer --image "$boot_final"
"$AVBTOOL" add_hash_footer --image "$boot_final" "${AVB_FOOTER_ARGS[@]}"

cp -f "$STOCK_BOOT" "$OUT/boot_a.stock.img"
cp -f "$boot_final" "$OUT/out/boot.img"

strings -a "$KERNEL_IMAGE" | grep -m1 'Linux version ' >"$OUT/out/kernel-version.txt" || true
"$AVBTOOL" info_image --image "$boot_final" >"$OUT/out/boot_a.avb.txt" 2>&1
"$AVBTOOL" verify_image --image "$boot_final" --key "$TESTKEY" >"$OUT/out/boot_a.verify.txt" 2>&1 || true

boot_size="$(stat -c '%s' "$boot_final")"
if [ "$boot_size" != "$BOOT_PARTITION_SIZE" ]; then
  echo "boot_a.img size mismatch: got $boot_size want $BOOT_PARTITION_SIZE" >&2
  exit 1
fi
if ! grep -q 'Successfully verified footer and SHA256_RSA4096' "$OUT/out/boot_a.verify.txt"; then
  echo "boot_a.img AVB verify failed:" >&2
  cat "$OUT/out/boot_a.verify.txt" >&2
  exit 1
fi

echo "boot cmdline: ${BOOT_CMDLINE:-<empty>}"
echo "boot_a.img size: $boot_size"
echo "kernel-version: $(cat "$OUT/out/kernel-version.txt")"
echo "verify:"
cat "$OUT/out/boot_a.verify.txt"