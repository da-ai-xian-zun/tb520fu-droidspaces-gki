#!/system/bin/sh
# Read-only loop/sparse diagnostics for upstream issue attachment.
# Safe on daily-driver devices: no mount, losetup attach, or dd.
# Usage: adb push .../sparse_issue_bundle.sh /data/local/tmp/ && adb shell su -c 'sh /data/local/tmp/sparse_issue_bundle.sh' | tee sparse-bundle.txt

set -eu

echo "=== sparse_issue_bundle $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

echo "--- device ---"
getprop ro.product.manufacturer 2>/dev/null || true
getprop ro.product.model 2>/dev/null || true
getprop ro.product.device 2>/dev/null || true
getprop ro.build.version.release 2>/dev/null || true
getprop ro.build.version.sdk 2>/dev/null || true
getprop ro.build.display.id 2>/dev/null || true
uname -r 2>/dev/null || true

echo "--- loop sysfs ---"
cat /sys/module/loop/parameters/max_loop 2>/dev/null || echo "(max_loop unreadable)"
ls -d /sys/block/loop* 2>/dev/null | wc -l | awk '{print "loop_devices:", $1}'
losetup -a 2>/dev/null | wc -l | awk '{print "losetup_bound:", $1}'

echo "--- apex backing_file count ---"
grep -h . /sys/block/loop*/loop/backing_file 2>/dev/null | grep -c apex || echo 0

echo "--- cmdline max_loop ---"
grep -o 'max_loop=[^ ]*' /proc/cmdline 2>/dev/null || echo "(no max_loop in cmdline)"

echo "--- droidspaces (if installed) ---"
DS=/data/local/Droidspaces/bin/droidspaces
if [ -x "$DS" ]; then
  ls -l "$DS" 2>/dev/null || true
  wc -c "$DS" 2>/dev/null || true
  sha256sum "$DS" 2>/dev/null || true
  "$DS" check 2>&1 | tail -20 || true
else
  echo "(droidspaces not at $DS)"
fi

echo "--- ulimit ---"
ulimit -n 2>/dev/null || true

echo "--- smoke: toybox mount -o loop (dry) ---"
echo "(skipped: would mutate loop state; run sparse_cli_app_compare.sh on test device)"

echo "=== end ==="