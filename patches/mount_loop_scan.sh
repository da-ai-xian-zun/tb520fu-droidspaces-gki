#!/system/bin/sh
# Sparse ext4 mount: busybox/system mount -o loop first, then high-minor loop-scan fallback.
# Android APEX-heavy pools: keep upstream mount order; scan upper pool after failure.
set -eu

IMG="${1:?img path}"
MNT="${2:?mount point}"
OPTS_NO_LOOP="${3:-rw,nodelalloc,noatime,nodiratime,init_itable=0}"

if [ -n "${BUSYBOX_PATH:-}" ] && [ -x "$BUSYBOX_PATH" ]; then
  BB="$BUSYBOX_PATH"
else
  BB="/data/local/Droidspaces/bin/busybox"
fi

LOOP_OPTS="loop,$OPTS_NO_LOOP"

# 1. Upstream order: busybox mount -o loop, then system mount -o loop
if [ -x "$BB" ] && "$BB" mount -t ext4 -o "$LOOP_OPTS" "$IMG" "$MNT" 2>/dev/null; then
  exit 0
fi
if mount -t ext4 -o "$LOOP_OPTS" "$IMG" "$MNT" 2>/dev/null; then
  exit 0
fi

# 2. Fallback: explicit losetup — scan upper pool (relative floor, not OEM-specific)
# Skip lowest max(16, max_loop/4) minors; APEX/OEM modules usually bind low slots.
loop_scan_start() {
  local max_loop="$1"
  local skip=$((max_loop / 4))
  [ "$skip" -lt 16 ] && skip=16
  [ "$skip" -gt "$max_loop" ] && skip=$max_loop
  local s=$((max_loop - skip))
  [ "$s" -lt 0 ] && s=0
  echo "$s"
}

effective_max_loop() {
  local sysfs=64 block_max=0 n p
  if [ -r /sys/module/loop/parameters/max_loop ]; then
    sysfs=$(cat /sys/module/loop/parameters/max_loop 2>/dev/null) || sysfs=64
    [ -z "$sysfs" ] && sysfs=64
  fi
  for p in /sys/block/loop[0-9]* /sys/block/loop[0-9][0-9]*; do
    [ -e "$p" ] || continue
    n=${p##*/loop}
    case $n in ''|*[!0-9]*) continue ;; esac
    [ "$n" -gt "$block_max" ] && block_max=$n
  done
  if [ $((block_max + 1)) -gt "$sysfs" ]; then
    echo $((block_max + 1))
  else
    echo "$sysfs"
  fi
}

max_used_minor() {
  awk 'NR>1 {if ($2+0 > m) m=$2+0} END {print m+0}' /proc/loops 2>/dev/null || echo 0
}

max_loop=$(effective_max_loop)
used_max=$(max_used_minor)

start=$(loop_scan_start "$max_loop")
if [ "$used_max" -ge "$start" ]; then
  start=$((used_max + 1))
fi
[ "$start" -ge "$max_loop" ] && start=$((max_loop - 1))

end=$((max_loop - 1))
if [ "$used_max" -gt "$end" ]; then
  end=$used_max
fi
[ "$end" -gt 255 ] && end=255

i=$end
while [ "$i" -ge "$start" ]; do
  loop_dev="/dev/block/loop$i"
  if losetup "$loop_dev" 2>/dev/null; then
    i=$((i - 1))
    continue
  fi
  if losetup "$loop_dev" "$IMG" 2>/dev/null; then
    if mount -t ext4 -o "$OPTS_NO_LOOP" "$loop_dev" "$MNT" 2>/dev/null; then
      exit 0
    fi
    umount "$MNT" 2>/dev/null || true
    losetup -d "$loop_dev" 2>/dev/null || true
  fi
  i=$((i - 1))
done

exit 1