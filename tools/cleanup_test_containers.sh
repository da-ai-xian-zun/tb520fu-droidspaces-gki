#!/system/bin/sh
# Remove sparse A/B test containers and reclaim space (TB520FU)
set -eu

DS=/data/local/Droidspaces/bin/droidspaces
BASE=/data/local/Droidspaces/Containers

TEST_NAMES="debian-cli-sparse-test cli-sb-test cli-sb-4g modtest-sparse sb sb-cli-test"

echo "========== STOP RUNNING =========="
for n in $TEST_NAMES debian-cli debian13; do
  "$DS" --name="$n" stop 2>/dev/null || true
done
sleep 2
"$DS" show 2>&1 || true

echo "========== REMOVE TEST DIRS =========="
for n in $TEST_NAMES; do
  d="$BASE/$n"
  if [ -e "$d" ]; then
    echo "Removing $d ..."
    umount "$d/rootfs" 2>/dev/null || true
    for i in $(seq 48 63); do
      if losetup -a 2>/dev/null | grep "loop$i" | grep -qF "$d/"; then
        losetup -d /dev/block/loop$i 2>/dev/null || true
      fi
    done
    rm -rf "$d"
    echo "  removed"
  else
    echo "Skip (absent): $d"
  fi
done

echo "========== TEMP FILES =========="
rm -f /data/local/tmp/sparse-ab-*.img /data/local/tmp/sparse-cli-test-mnt 2>/dev/null || true
rm -rf /data/local/tmp/sparse-ab-*-mnt /data/local/tmp/diag-loop-test-mnt 2>/dev/null || true
rmdir /data/local/tmp/sparse-cli-test-mnt 2>/dev/null || true

echo "========== DISK AFTER =========="
du -sh "$BASE"/* 2>/dev/null || true
df -h /data | tail -1
echo "========== DONE CLEANUP =========="