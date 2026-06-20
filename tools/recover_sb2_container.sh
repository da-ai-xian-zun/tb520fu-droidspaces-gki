#!/system/bin/sh
# Recover sb2 after App install stuck on umount (image already valid).
set -eu
BASE=/data/local/Droidspaces/Containers/sb2
IMG="$BASE/rootfs.img"
CFG="$BASE/container.config"
MP="$BASE/rootfs"

echo "[*] Recover sb2 $(date)"

# Best-effort cleanup from stuck install
mkdir -p "$MP"
/data/local/Droidspaces/bin/busybox umount -l "$MP" 2>/dev/null || umount -l "$MP" 2>/dev/null || true
for d in $(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1); do
  losetup -d "$d" 2>/dev/null || true
done
rmdir "$MP" 2>/dev/null || true

if [ ! -f "$IMG" ]; then
  echo "[!] missing $IMG"; exit 1
fi

# Verify image
mkdir -p "$MP"
if ! losetup /dev/block/loop52 "$IMG" 2>/dev/null; then
  losetup /dev/block/loop53 "$IMG" 2>/dev/null || { echo "[!] losetup fail"; exit 1; }
fi
DEV=$(losetup -a 2>/dev/null | grep -F "$IMG" | cut -d: -f1 | head -1)
mount -t ext4 -o ro "$DEV" "$MP" 2>/dev/null || { echo "[!] mount verify fail"; exit 1; }
if [ ! -f "$MP/etc/os-release" ]; then
  echo "[!] image not a rootfs"; umount "$MP"; exit 1
fi
umount "$MP"
losetup -d "$DEV" 2>/dev/null || true
rmdir "$MP"

if [ -f "$CFG" ]; then
  echo "[=] config already exists"; cat "$CFG"; exit 0
fi

UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || date +%s)
cat > "$CFG" << EOF
# Droidspaces Container Configuration
# Generated automatically - Changes may be overwritten

name=sb2
hostname=sb2
rootfs_path=$IMG
disable_ipv6=0
enable_android_storage=0
enable_termux_x11=0
enable_virgl=0
enable_pulseaudio=0
enable_hw_access=0
enable_gpu_mode=0
selinux_permissive=0
volatile_mode=0
force_cgroupv1=0
block_nested_ns=0
foreground=0
net_mode=nat
static_nat_ip=172.28.1.4
uuid=$UUID
run_at_boot=0
use_sparse_image=1
sparse_image_size_gb=4
EOF
chmod 644 "$CFG"
echo "[+] wrote $CFG"
cat "$CFG"
echo "[+] sb2 recovered — force-stop App, refresh container list"