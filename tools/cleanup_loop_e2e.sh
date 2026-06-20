#!/system/bin/sh
# Remove apk-e2e-sparse test residue (loop62 leak).
set -eu
BASE=/data/local/Droidspaces/Containers/apk-e2e-sparse
IMG="$BASE/rootfs.img"
MP="$BASE/rootfs"
ALT_MP=/data/local/tmp/apk-e2e-mnt

echo "[*] cleanup apk-e2e loop residue $(date)"

for m in "$MP" "$ALT_MP"; do
  [ -d "$m" ] && umount -l "$m" 2>/dev/null || true
done

if [ -f "$IMG" ]; then
  for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do
    echo "[*] detach $d"
    losetup -d "$d" 2>/dev/null || true
  done
fi

for d in $(losetup -a 2>/dev/null | grep -F "apk-e2e" | cut -d: -f1); do
  echo "[*] detach $d (apk-e2e)"
  losetup -d "$d" 2>/dev/null || true
done

rm -rf "$BASE" "$ALT_MP" 2>/dev/null || true

echo "[*] losetup -a count=$(losetup -a 2>/dev/null | wc -l)"
losetup -a 2>/dev/null | grep -F apk-e2e || echo "[+] no apk-e2e loops"