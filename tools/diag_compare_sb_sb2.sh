#!/system/bin/sh
probe() {
  n="$1"
  img="/data/local/Droidspaces/Containers/$n/rootfs.img"
  dev="$2"
  mnt="/data/local/tmp/cmp-$n"
  mkdir -p "$mnt"
  losetup -d "/dev/block/$dev" 2>/dev/null
  losetup "/dev/block/$dev" "$img" 2>/dev/null || { echo "$n losetup fail"; return; }
  mount -t ext4 -o ro "/dev/block/$dev" "$mnt" 2>/dev/null || { echo "$n mount fail"; losetup -d "/dev/block/$dev"; return; }
  echo "=== $n ==="
  ls -la "/data/local/Droidspaces/Containers/$n/container.config" 2>/dev/null || echo "no config"
  ls -la "$mnt/etc/droidspaces" "$mnt/etc/machine-id" 2>/dev/null
  du -sh "$mnt" 2>/dev/null
  umount "$mnt"; losetup -d "/dev/block/$dev"; rmdir "$mnt"
}
probe sb loop56
probe sb2 loop55
echo "loops for containers:"
losetup -a 2>/dev/null | grep -E 'sb|apk-e2e' || true