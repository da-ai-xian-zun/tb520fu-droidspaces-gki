#!/system/bin/sh
# Minimal sb2 recovery: write container.config only (image already verified).
set -eu
BASE=/data/local/Droidspaces/Containers/sb2
CFG="$BASE/container.config"
IMG="$BASE/rootfs.img"

echo "[*] minimal recover sb2 $(date)"

if [ ! -f "$IMG" ]; then
  echo "[!] missing $IMG"
  exit 1
fi

if [ -f "$CFG" ]; then
  echo "[=] config exists"
  cat "$CFG"
  exit 0
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