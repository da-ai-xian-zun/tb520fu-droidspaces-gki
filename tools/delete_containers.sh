#!/system/bin/sh
# Delete named containers: umount, detach loops, rm -rf.
set -eu
BASE=/data/local/Droidspaces/Containers
DS=/data/local/Droidspaces/bin/droidspaces

cleanup_one() {
  name="$1"
  dir="$BASE/$name"
  [ -d "$dir" ] || { echo "[=] $name: not found"; return 0; }

  img="$dir/rootfs.img"
  mp="$dir/rootfs"
  host_mp="/mnt/Droidspaces/$name"

  echo "[*] cleaning $name ..."
  "$DS" --name="$name" stop 2>/dev/null || true
  umount -l "$host_mp" 2>/dev/null || true
  mkdir -p "$mp" 2>/dev/null || true
  /data/local/Droidspaces/bin/busybox umount -l "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
  if [ -f "$img" ]; then
    for d in $(losetup -a 2>/dev/null | grep -F "$img" | cut -d: -f1); do
      losetup -d "$d" 2>/dev/null || true
    done
  fi
  rm -rf "$dir"
  echo "[+] deleted $name"
}

for c in "$@"; do
  cleanup_one "$c"
done

echo "[*] remaining containers:"
ls -la "$BASE" 2>/dev/null || true
echo "[*] free space:"
df -h /data 2>/dev/null | tail -1