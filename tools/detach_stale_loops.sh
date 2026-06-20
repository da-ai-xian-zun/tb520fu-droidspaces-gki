#!/system/bin/sh
set -eu
echo "[*] detach stale sb/sba loops $(date)"
umount -l /mnt/Droidspaces/sb 2>/dev/null || true
umount -l /mnt/Droidspaces/sba 2>/dev/null || true
for d in $(losetup -a 2>/dev/null | grep -E 'Containers/sb|Containers/sba' | cut -d: -f1); do
  echo "[*] losetup -d $d"
  losetup -d "$d" 2>/dev/null || true
done
losetup -a 2>/dev/null | grep -E 'Containers/sb|Containers/sba' || echo "[+] no sb/sba loops"
echo "[*] bound=$(losetup -a 2>/dev/null | wc -l)"