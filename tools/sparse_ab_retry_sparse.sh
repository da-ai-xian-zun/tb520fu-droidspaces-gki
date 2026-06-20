#!/system/bin/sh
set -eu
DS=/data/local/Droidspaces/bin/droidspaces
TEST=debian-cli-sparse-test
IMG=/data/local/Droidspaces/Containers/debian-cli-sparse-test/rootfs.img
MP=/data/local/tmp/sparse-ab-fill-mnt
LOG=/data/local/tmp/sparse_ab_results.txt

echo "=== cleanup loops ===" | tee -a "$LOG"
umount "$MP" 2>/dev/null || true
umount /mnt/Droidspaces/debian-cli-sparse-test 2>/dev/null || true
sync
for i in $(seq 0 63); do
  losetup -d /dev/block/loop$i 2>/dev/null || true
done
sleep 2
echo "bound after cleanup: $(losetup -a 2>/dev/null | wc -l)" | tee -a "$LOG"
losetup -a 2>/dev/null | grep -F "$IMG" || echo "(img not bound)" | tee -a "$LOG"

BENCH='echo "========== BENCH sparse =========="; mount | head -8; df -h / /tmp 2>/dev/null | head -4; t0=$(date +%s%N); for i in $(seq 1 500); do stat /etc/passwd >/dev/null; done; t1=$(date +%s%N); echo "sparse stat_x500: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); ls -1 /usr/share >/dev/null; t1=$(date +%s%N); echo "sparse ls_usr_share: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /usr/share -maxdepth 2 -type f >/dev/null; t1=$(date +%s%N); echo "sparse find_usr_share_d2: $(( (t1-t0)/1000000 )) ms"; t0=$(date +%s%N); find /root -maxdepth 2 >/dev/null 2>&1; t1=$(date +%s%N); echo "sparse find_root_d2: $(( (t1-t0)/1000000 )) ms"; if command -v apt-get >/dev/null 2>&1; then t0=$(date +%s%N); apt-get update -qq >/dev/null 2>&1 || true; t1=$(date +%s%N); echo "sparse apt_update: $(( (t1-t0)/1000000 )) ms"; fi; echo "========== END sparse =========="'

echo "=== start sparse test ===" | tee -a "$LOG"
"$DS" --name="$TEST" --rootfs-img="$IMG" --hostname="$TEST" \
  --net=nat --upstream=wlan0 --dns=1.1.1.1,8.8.8.8 start 2>&1 | tee -a "$LOG"
sleep 8
"$DS" show 2>&1 | tee -a "$LOG"
"$DS" --name="$TEST" run sh -c "$BENCH" 2>&1 | tee -a "$LOG"
"$DS" --name="$TEST" stop 2>&1 | tee -a "$LOG"
echo "=== DONE ===" | tee -a "$LOG"
cat "$LOG"